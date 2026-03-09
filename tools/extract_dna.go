/*
 * extract_dna.go — Extract D.N.A. (Dynamic Neural Ancestry) from GGUF weights
 *
 * Reads a nanollama GGUF model and extracts structural skeleton:
 *   1. Gravity — token embedding norms (which words are "heavy")
 *   2. Co-activation — top token pairs from attention output projections
 *   3. Destiny — mean direction vector from final layer
 *
 * Output: leo.h (C header with static const arrays)
 *
 * Usage: go run extract_dna.go <model.gguf> [output.h]
 *
 * Arianna → Leo. Mother → Son. θ = ε + γ + αδ
 */
package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"os"
	"sort"
	"strings"
)

/* ── GGUF constants ── */
const (
	GGUF_MAGIC = 0x46554747 // "GGUF" as little-endian uint32

	GGUF_TYPE_UINT8   = 0
	GGUF_TYPE_INT8    = 1
	GGUF_TYPE_UINT16  = 2
	GGUF_TYPE_INT16   = 3
	GGUF_TYPE_UINT32  = 4
	GGUF_TYPE_INT32   = 5
	GGUF_TYPE_FLOAT32 = 6
	GGUF_TYPE_BOOL    = 7
	GGUF_TYPE_STRING  = 8
	GGUF_TYPE_ARRAY   = 9
	GGUF_TYPE_UINT64  = 10
	GGUF_TYPE_INT64   = 11
	GGUF_TYPE_FLOAT64 = 12

	/* tensor data types */
	GGML_TYPE_F32  = 0
	GGML_TYPE_F16  = 1
	GGML_TYPE_Q4_0 = 2
	GGML_TYPE_Q4_1 = 3
	GGML_TYPE_Q8_0 = 8

	/* DNA extraction params */
	MAX_GRAVITY_WORDS = 2048
	MAX_COACTIVATION  = 4096
	DESTINY_DIM       = 128 /* Leo's internal dim */
)

/* ── GGUF reader ── */

type GGUFReader struct {
	f       *os.File
	version uint32
}

func (r *GGUFReader) readU8() uint8 {
	var v uint8
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readU16() uint16 {
	var v uint16
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readU32() uint32 {
	var v uint32
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readI32() int32 {
	var v int32
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readU64() uint64 {
	var v uint64
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readI64() int64 {
	var v int64
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readF32() float32 {
	var v float32
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readF64() float64 {
	var v float64
	binary.Read(r.f, binary.LittleEndian, &v)
	return v
}

func (r *GGUFReader) readBool() bool {
	return r.readU8() != 0
}

func (r *GGUFReader) readString() string {
	var n uint64
	binary.Read(r.f, binary.LittleEndian, &n)
	buf := make([]byte, n)
	io.ReadFull(r.f, buf)
	return string(buf)
}

func (r *GGUFReader) skipValue(typ uint32) {
	switch typ {
	case GGUF_TYPE_UINT8, GGUF_TYPE_INT8, GGUF_TYPE_BOOL:
		r.readU8()
	case GGUF_TYPE_UINT16, GGUF_TYPE_INT16:
		r.readU16()
	case GGUF_TYPE_UINT32, GGUF_TYPE_INT32:
		r.readU32()
	case GGUF_TYPE_FLOAT32:
		r.readF32()
	case GGUF_TYPE_UINT64, GGUF_TYPE_INT64:
		r.readU64()
	case GGUF_TYPE_FLOAT64:
		r.readF64()
	case GGUF_TYPE_STRING:
		r.readString()
	case GGUF_TYPE_ARRAY:
		atype := r.readU32()
		alen := r.readU64()
		for i := uint64(0); i < alen; i++ {
			r.skipValue(atype)
		}
	}
}

func (r *GGUFReader) readMetaValue(typ uint32) interface{} {
	switch typ {
	case GGUF_TYPE_UINT32:
		return r.readU32()
	case GGUF_TYPE_INT32:
		return r.readI32()
	case GGUF_TYPE_FLOAT32:
		return r.readF32()
	case GGUF_TYPE_STRING:
		return r.readString()
	case GGUF_TYPE_UINT64:
		return r.readU64()
	case GGUF_TYPE_INT64:
		return r.readI64()
	default:
		r.skipValue(typ)
		return nil
	}
}

/* ── Tensor info ── */

type TensorInfo struct {
	Name   string
	NDims  uint32
	Dims   [4]uint64
	Type   uint32
	Offset uint64
}

/* ── f16 → f32 conversion ── */

func f16tof32(h uint16) float32 {
	sign := uint32(h>>15) & 1
	exp := uint32(h>>10) & 0x1f
	mant := uint32(h) & 0x3ff

	if exp == 0 {
		if mant == 0 {
			return math.Float32frombits(sign << 31)
		}
		/* denormalized */
		for mant&0x400 == 0 {
			mant <<= 1
			exp--
		}
		exp++
		mant &= 0x3ff
		exp += 127 - 15
		return math.Float32frombits((sign << 31) | (exp << 23) | (mant << 13))
	} else if exp == 31 {
		return math.Float32frombits((sign << 31) | (0xff << 23) | (mant << 13))
	}

	exp += 127 - 15
	return math.Float32frombits((sign << 31) | (exp << 23) | (mant << 13))
}

/* ── Read tensor data as f32 ── */

func readTensorF32(f *os.File, info TensorInfo, dataOffset int64) []float32 {
	nelem := uint64(1)
	for d := uint32(0); d < info.NDims; d++ {
		nelem *= info.Dims[d]
	}

	f.Seek(dataOffset+int64(info.Offset), io.SeekStart)

	result := make([]float32, nelem)

	switch info.Type {
	case GGML_TYPE_F32:
		binary.Read(f, binary.LittleEndian, result)
	case GGML_TYPE_F16:
		raw := make([]uint16, nelem)
		binary.Read(f, binary.LittleEndian, raw)
		for i, h := range raw {
			result[i] = f16tof32(h)
		}
	default:
		fmt.Fprintf(os.Stderr, "warning: tensor %s has type %d, skipping\n", info.Name, info.Type)
		return nil
	}

	return result
}

/* ── Gravity: L2 norm of each row in token_embd ── */

type GravityEntry struct {
	Index int
	Norm  float32
}

func extractGravity(embeddings []float32, vocabSize, dim int) []GravityEntry {
	entries := make([]GravityEntry, vocabSize)
	for i := 0; i < vocabSize; i++ {
		row := embeddings[i*dim : (i+1)*dim]
		var sum float32
		for _, v := range row {
			sum += v * v
		}
		entries[i] = GravityEntry{Index: i, Norm: float32(math.Sqrt(float64(sum)))}
	}

	/* sort by norm descending */
	sort.Slice(entries, func(a, b int) bool {
		return entries[a].Norm > entries[b].Norm
	})

	n := vocabSize
	if n > MAX_GRAVITY_WORDS {
		n = MAX_GRAVITY_WORDS
	}
	return entries[:n]
}

/* ── Co-activation: top pairs from attention output projection ── */

type CoactPair struct {
	Src, Dst int
	Strength float32
}

func extractCoactivation(attnOut []float32, dim int) []CoactPair {
	/* attnOut is [dim x dim] — the output projection matrix
	 * Co-activation: dot product of row i and row j tells us
	 * how much token i and token j activate together
	 * We compute this for a subset and take top pairs */

	n := dim
	if n > 512 {
		n = 512 /* cap for memory */
	}

	/* compute pairwise dot products for first n rows */
	var pairs []CoactPair
	for i := 0; i < n; i++ {
		ri := attnOut[i*dim : (i+1)*dim]
		for j := i + 1; j < n; j++ {
			rj := attnOut[j*dim : (j+1)*dim]
			var dot float32
			for k := 0; k < dim; k++ {
				dot += ri[k] * rj[k]
			}
			if dot > 0.1 { /* threshold */
				pairs = append(pairs, CoactPair{Src: i, Dst: j, Strength: dot})
			}
		}
	}

	sort.Slice(pairs, func(a, b int) bool {
		return pairs[a].Strength > pairs[b].Strength
	})

	if len(pairs) > MAX_COACTIVATION {
		pairs = pairs[:MAX_COACTIVATION]
	}
	return pairs
}

/* ── Destiny: mean of final layer output weights → project to Leo dim ── */

func extractDestiny(weights []float32, rows, cols int) []float32 {
	/* average across rows to get direction vector */
	dest := make([]float32, cols)
	for i := 0; i < rows; i++ {
		for j := 0; j < cols; j++ {
			dest[j] += weights[i*cols+j]
		}
	}
	/* normalize */
	var norm float32
	for j := 0; j < cols; j++ {
		dest[j] /= float32(rows)
		norm += dest[j] * dest[j]
	}
	norm = float32(math.Sqrt(float64(norm)))
	if norm > 0 {
		for j := range dest {
			dest[j] /= norm
		}
	}

	/* project to DESTINY_DIM by averaging chunks */
	if cols <= DESTINY_DIM {
		result := make([]float32, DESTINY_DIM)
		copy(result, dest)
		return result
	}

	result := make([]float32, DESTINY_DIM)
	chunkSize := cols / DESTINY_DIM
	for i := 0; i < DESTINY_DIM; i++ {
		var sum float32
		for j := 0; j < chunkSize; j++ {
			idx := i*chunkSize + j
			if idx < cols {
				sum += dest[idx]
			}
		}
		result[i] = sum / float32(chunkSize)
	}

	/* re-normalize */
	norm = 0
	for _, v := range result {
		norm += v * v
	}
	norm = float32(math.Sqrt(float64(norm)))
	if norm > 0 {
		for i := range result {
			result[i] /= norm
		}
	}

	return result
}

/* ── Read BPE vocab from GGUF metadata ── */

func readVocab(f *os.File, r *GGUFReader, nMeta uint64) []string {
	f.Seek(0, io.SeekStart)

	/* re-read header */
	r.readU32() /* magic */
	r.readU32() /* version */
	r.readU64() /* n_tensors */
	r.readU64() /* n_meta */

	var tokens []string

	for i := uint64(0); i < nMeta; i++ {
		key := r.readString()
		vtype := r.readU32()

		if key == "tokenizer.ggml.tokens" {
			if vtype == GGUF_TYPE_ARRAY {
				atype := r.readU32()
				alen := r.readU64()
				tokens = make([]string, alen)
				for j := uint64(0); j < alen; j++ {
					if atype == GGUF_TYPE_STRING {
						tokens[j] = r.readString()
					} else {
						r.skipValue(atype)
					}
				}
			} else {
				r.skipValue(vtype)
			}
		} else {
			r.skipValue(vtype)
		}
	}

	return tokens
}

/* ── Generate C header ── */

func writeHeader(out *os.File, vocab []string, gravity []GravityEntry,
	coact []CoactPair, destiny []float32) {

	fmt.Fprintf(out, "/*\n")
	fmt.Fprintf(out, " * leo.h — D.N.A. (Dynamic Neural Ancestry)\n")
	fmt.Fprintf(out, " *\n")
	fmt.Fprintf(out, " * Auto-generated from mini-arianna-f16.gguf\n")
	fmt.Fprintf(out, " * Arianna → Leo. Mother → Son.\n")
	fmt.Fprintf(out, " * θ = ε + γ + αδ\n")
	fmt.Fprintf(out, " *\n")
	fmt.Fprintf(out, " * DO NOT EDIT — regenerate with: go run tools/extract_dna.go\n")
	fmt.Fprintf(out, " */\n\n")
	fmt.Fprintf(out, "#ifndef LEO_DNA_H\n")
	fmt.Fprintf(out, "#define LEO_DNA_H\n\n")

	/* ── Gravity ── */
	fmt.Fprintf(out, "/* Gravity: token importance (L2 norm of embedding row) */\n")
	fmt.Fprintf(out, "#define DNA_GRAVITY_SIZE %d\n\n", len(gravity))

	fmt.Fprintf(out, "static const char *DNA_GRAVITY_WORDS[] = {\n")
	for i, g := range gravity {
		word := "UNK"
		if g.Index < len(vocab) {
			word = strings.ReplaceAll(vocab[g.Index], "\\", "\\\\")
			word = strings.ReplaceAll(word, "\"", "\\\"")
			word = strings.ReplaceAll(word, "\n", "\\n")
			word = strings.ReplaceAll(word, "\r", "")
		}
		if i < len(gravity)-1 {
			fmt.Fprintf(out, "    \"%s\",\n", word)
		} else {
			fmt.Fprintf(out, "    \"%s\"\n", word)
		}
	}
	fmt.Fprintf(out, "};\n\n")

	fmt.Fprintf(out, "static const float DNA_GRAVITY_VALUES[] = {\n")
	for i, g := range gravity {
		if i < len(gravity)-1 {
			fmt.Fprintf(out, "    %.6ff,\n", g.Norm)
		} else {
			fmt.Fprintf(out, "    %.6ff\n", g.Norm)
		}
	}
	fmt.Fprintf(out, "};\n\n")

	/* ── Co-activation ── */
	fmt.Fprintf(out, "/* Co-activation: token pairs that fire together */\n")
	fmt.Fprintf(out, "#define DNA_COACTIVATION_SIZE %d\n\n", len(coact))

	fmt.Fprintf(out, "static const char *DNA_COACT_SRC[] = {\n")
	for i, c := range coact {
		word := "UNK"
		if c.Src < len(vocab) {
			word = strings.ReplaceAll(vocab[c.Src], "\\", "\\\\")
			word = strings.ReplaceAll(word, "\"", "\\\"")
			word = strings.ReplaceAll(word, "\n", "\\n")
			word = strings.ReplaceAll(word, "\r", "")
		}
		comma := ","
		if i == len(coact)-1 {
			comma = ""
		}
		fmt.Fprintf(out, "    \"%s\"%s\n", word, comma)
	}
	fmt.Fprintf(out, "};\n\n")

	fmt.Fprintf(out, "static const char *DNA_COACT_DST[] = {\n")
	for i, c := range coact {
		word := "UNK"
		if c.Dst < len(vocab) {
			word = strings.ReplaceAll(vocab[c.Dst], "\\", "\\\\")
			word = strings.ReplaceAll(word, "\"", "\\\"")
			word = strings.ReplaceAll(word, "\n", "\\n")
			word = strings.ReplaceAll(word, "\r", "")
		}
		comma := ","
		if i == len(coact)-1 {
			comma = ""
		}
		fmt.Fprintf(out, "    \"%s\"%s\n", word, comma)
	}
	fmt.Fprintf(out, "};\n\n")

	fmt.Fprintf(out, "static const float DNA_COACT_STRENGTH[] = {\n")
	for i, c := range coact {
		comma := ","
		if i == len(coact)-1 {
			comma = ""
		}
		fmt.Fprintf(out, "    %.6ff%s\n", c.Strength, comma)
	}
	fmt.Fprintf(out, "};\n\n")

	/* ── Destiny ── */
	fmt.Fprintf(out, "/* Destiny: initial direction vector from ancestor */\n")
	fmt.Fprintf(out, "#define DNA_DESTINY_DIM %d\n\n", len(destiny))

	fmt.Fprintf(out, "static const float DNA_DESTINY_VECTOR[] = {\n")
	for i, v := range destiny {
		comma := ","
		if i == len(destiny)-1 {
			comma = ""
		}
		fmt.Fprintf(out, "    %.8ff%s\n", v, comma)
	}
	fmt.Fprintf(out, "};\n\n")

	fmt.Fprintf(out, "#endif /* LEO_DNA_H */\n")
}

/* ── Main ── */

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "usage: %s <model.gguf> [output.h]\n", os.Args[0])
		os.Exit(1)
	}

	ggufPath := os.Args[1]
	outPath := "leo.h"
	if len(os.Args) > 2 {
		outPath = os.Args[2]
	}

	f, err := os.Open(ggufPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	defer f.Close()

	r := &GGUFReader{f: f}

	/* ── Read GGUF header ── */
	magic := r.readU32()
	if magic != GGUF_MAGIC {
		fmt.Fprintf(os.Stderr, "error: not a GGUF file (magic: 0x%08x)\n", magic)
		os.Exit(1)
	}

	r.version = r.readU32()
	nTensors := r.readU64()
	nMeta := r.readU64()

	fmt.Printf("[dna] GGUF v%d: %d tensors, %d metadata entries\n", r.version, nTensors, nMeta)

	/* ── Read metadata (skip most, capture what we need) ── */
	var vocabSize uint32
	var dim uint32
	var nLayers uint32

	for i := uint64(0); i < nMeta; i++ {
		key := r.readString()
		vtype := r.readU32()

		switch key {
		case "llama.embedding_length":
			v := r.readMetaValue(vtype)
			if u, ok := v.(uint32); ok {
				dim = u
			}
		case "llama.block_count":
			v := r.readMetaValue(vtype)
			if u, ok := v.(uint32); ok {
				nLayers = u
			}
		case "tokenizer.ggml.tokens":
			/* count tokens */
			if vtype == GGUF_TYPE_ARRAY {
				atype := r.readU32()
				alen := r.readU64()
				vocabSize = uint32(alen)
				for j := uint64(0); j < alen; j++ {
					r.skipValue(atype)
				}
			} else {
				r.skipValue(vtype)
			}
		default:
			r.skipValue(vtype)
		}
	}

	fmt.Printf("[dna] model: dim=%d, layers=%d, vocab=%d\n", dim, nLayers, vocabSize)

	/* ── Read tensor infos ── */
	tensors := make([]TensorInfo, nTensors)
	for i := uint64(0); i < nTensors; i++ {
		t := TensorInfo{}
		t.Name = r.readString()
		t.NDims = r.readU32()
		for d := uint32(0); d < t.NDims; d++ {
			t.Dims[d] = r.readU64()
		}
		t.Type = r.readU32()
		t.Offset = r.readU64()
		tensors[i] = t
	}

	/* data section starts at aligned offset */
	pos, _ := f.Seek(0, io.SeekCurrent)
	alignment := int64(32)
	if pos%alignment != 0 {
		pos = ((pos / alignment) + 1) * alignment
	}
	dataOffset := pos

	fmt.Printf("[dna] data offset: %d\n", dataOffset)

	/* ── Find tensors we need ── */
	var embedTensor, attnOutTensor, outputTensor *TensorInfo

	for i := range tensors {
		t := &tensors[i]
		switch {
		case t.Name == "token_embd.weight":
			embedTensor = t
			fmt.Printf("[dna] found: %s [%dx%d] type=%d\n", t.Name, t.Dims[0], t.Dims[1], t.Type)
		case strings.Contains(t.Name, fmt.Sprintf("blk.%d.attn_output.weight", nLayers-1)):
			attnOutTensor = t
			fmt.Printf("[dna] found: %s [%dx%d] type=%d\n", t.Name, t.Dims[0], t.Dims[1], t.Type)
		case t.Name == "output.weight":
			outputTensor = t
			fmt.Printf("[dna] found: %s [%dx%d] type=%d\n", t.Name, t.Dims[0], t.Dims[1], t.Type)
		}
	}

	if embedTensor == nil {
		fmt.Fprintf(os.Stderr, "error: token_embd.weight not found\n")
		os.Exit(1)
	}

	/* ── Read vocab (second pass) ── */
	fmt.Printf("[dna] reading vocabulary...\n")
	vocab := readVocab(f, r, nMeta)
	fmt.Printf("[dna] vocab: %d tokens\n", len(vocab))

	/* ── Extract gravity from embeddings ── */
	fmt.Printf("[dna] extracting gravity from embeddings...\n")
	embedData := readTensorF32(f, *embedTensor, dataOffset)
	if embedData == nil {
		fmt.Fprintf(os.Stderr, "error: could not read embedding tensor\n")
		os.Exit(1)
	}
	gravity := extractGravity(embedData, int(vocabSize), int(dim))
	fmt.Printf("[dna] gravity: %d entries (top norm: %.4f)\n", len(gravity), gravity[0].Norm)

	/* ── Extract co-activation from attention output ── */
	var coact []CoactPair
	if attnOutTensor != nil {
		fmt.Printf("[dna] extracting co-activation from attention output...\n")
		attnData := readTensorF32(f, *attnOutTensor, dataOffset)
		if attnData != nil {
			coact = extractCoactivation(attnData, int(dim))
			fmt.Printf("[dna] co-activation: %d pairs\n", len(coact))
		}
	}
	if len(coact) == 0 {
		fmt.Printf("[dna] warning: no co-activation data, using embedding similarity\n")
		/* fallback: use embedding dot products */
		coact = extractCoactivationFromEmbed(embedData, int(vocabSize), int(dim))
		fmt.Printf("[dna] co-activation (from embeddings): %d pairs\n", len(coact))
	}

	/* ── Extract destiny from output weights ── */
	var destiny []float32
	if outputTensor != nil {
		fmt.Printf("[dna] extracting destiny from output layer...\n")
		outputData := readTensorF32(f, *outputTensor, dataOffset)
		if outputData != nil {
			rows := int(outputTensor.Dims[1])
			cols := int(outputTensor.Dims[0])
			if rows == 0 {
				rows = int(vocabSize)
				cols = int(dim)
			}
			destiny = extractDestiny(outputData, rows, cols)
		}
	}
	if destiny == nil {
		fmt.Printf("[dna] using embedding mean as destiny fallback\n")
		destiny = extractDestiny(embedData, int(vocabSize), int(dim))
	}
	fmt.Printf("[dna] destiny: %d dimensions\n", len(destiny))

	/* ── Write leo.h ── */
	out, err := os.Create(outPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error creating output: %v\n", err)
		os.Exit(1)
	}
	defer out.Close()

	writeHeader(out, vocab, gravity, coact, destiny)

	fi, _ := out.Stat()
	fmt.Printf("[dna] wrote %s (%d bytes)\n", outPath, fi.Size())
	fmt.Printf("[dna] Arianna → Leo. DNA transfer complete.\n")
}

/* fallback co-activation from embedding similarity */
func extractCoactivationFromEmbed(embedData []float32, vocabSize, dim int) []CoactPair {
	n := vocabSize
	if n > 1024 {
		n = 1024
	}

	/* pre-compute norms */
	norms := make([]float32, n)
	for i := 0; i < n; i++ {
		var s float32
		for d := 0; d < dim; d++ {
			v := embedData[i*dim+d]
			s += v * v
		}
		norms[i] = float32(math.Sqrt(float64(s)))
	}

	var pairs []CoactPair
	for i := 0; i < n; i++ {
		if norms[i] < 1e-6 {
			continue
		}
		ri := embedData[i*dim : (i+1)*dim]
		for j := i + 1; j < n; j++ {
			if norms[j] < 1e-6 {
				continue
			}
			rj := embedData[j*dim : (j+1)*dim]
			var dot float32
			for k := 0; k < dim; k++ {
				dot += ri[k] * rj[k]
			}
			cosine := dot / (norms[i] * norms[j])
			if cosine > 0.5 { /* high similarity threshold */
				pairs = append(pairs, CoactPair{Src: i, Dst: j, Strength: cosine})
			}
		}
	}

	sort.Slice(pairs, func(a, b int) bool {
		return pairs[a].Strength > pairs[b].Strength
	})

	if len(pairs) > MAX_COACTIVATION {
		pairs = pairs[:MAX_COACTIVATION]
	}
	return pairs
}
