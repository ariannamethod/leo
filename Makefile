CC      ?= cc
CFLAGS  ?= -O2 -Wall
LDFLAGS  = -lm -lsqlite3 -lpthread

.PHONY: all clean neoleo inner test

# Default: build Leo with D.N.A.
all: leo

# Standalone organism (C only, with D.N.A.)
leo: leo.c leo.h
	$(CC) $(CFLAGS) -DLEO_HAS_DNA leo.c $(LDFLAGS) -o $@

# Without D.N.A. — pure weightless organism
leo-naked: leo.c
	$(CC) $(CFLAGS) leo.c $(LDFLAGS) -o $@

# Single-file organism (neoleo.c = leo.c + leo.h inline)
neoleo: neoleo.c
	$(CC) $(CFLAGS) neoleo.c $(LDFLAGS) -o $@

neoleo.c: leo.c leo.h tools/make_neoleo.sh
	bash tools/make_neoleo.sh

# Inner world (Go + CGO)
inner:
	cd inner && go build -o ../leo_inner .

# Run tests
test: leo
	cd inner && go test -v ./...

# Extract D.N.A. from GGUF weights (requires Go + GGUF file)
# Usage: make dna GGUF=path/to/model.gguf
dna:
	go run tools/extract_dna.go $(GGUF) > leo.h

# Generate bootstrap dataset
leo.txt:
	go run tools/gen_leo_txt.go > leo.txt

clean:
	rm -f leo leo-naked neoleo leo_inner neoleo.c
	rm -f *.o *.db *.db-journal *.db-wal *.db-shm *.db.state
