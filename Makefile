# Leo Inner World — Makefile
# Build the Go emotional resonance engine

.PHONY: all build clean test

# Default target
all: build

# Build the shared library
build:
	@echo "🔨 Building libleo_inner.so..."
	cd inner_world && go build -buildmode=c-shared -o libleo_inner.so emotional_resonance.go
	@echo "✅ Built: inner_world/libleo_inner.so"

# Clean build artifacts
clean:
	rm -f inner_world/libleo_inner.so inner_world/libleo_inner.h
	@echo "🧹 Cleaned build artifacts"

# Test the library from Python
test: build
	@echo "🧪 Testing Go library from Python..."
	python3 -c "from ctypes import cdll, c_float; \
		lib = cdll.LoadLibrary('./inner_world/libleo_inner.so'); \
		lib.leo_get_valence.restype = c_float; \
		lib.leo_reset_state(); \
		lib.leo_emotional_drift(c_float(0.8), c_float(0.5)); \
		print(f'Valence after love: {lib.leo_get_valence():.2f}'); \
		print('✅ Go library works!')"

# Run REPL demo
repl:
	PYTHONPATH=. python3 tests/repl_mode_demo.py

# Run all tests
pytest:
	PYTHONPATH=. python3 -m pytest tests/ -v --timeout=60
