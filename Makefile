CC      ?= cc
CFLAGS  ?= -O2 -lm -Wall -Wextra
SANED    = -O1 -g -fsanitize=address,undefined -lm -Wall -Wextra

# AML velocity bridge — build & link the family language so an .aml script can
# drive Leo's breath (--aml). The language is vendored as SOURCE in ariannamethod/
# (built into libaml.a here, never committed as a binary — AML itself .gitignores
# *.a). VENDOR ONLY — no sibling/external checkout reference. If the vendored source
# is absent, a silent fallback (Leo runs full; --aml just reports it is not linked).
AML_SRC := ariannamethod/ariannamethod.c
AML_LIB :=
ifneq ($(wildcard $(AML_SRC)),)   # the ONLY AML source is the vendored copy in ariannamethod/
  AML_LIB   := ariannamethod/libaml.a
  AML_FLAGS := -DHAVE_AML -Iariannamethod
endif

.PHONY: all test asan clean run

all: leo

ariannamethod/libaml.a: $(AML_SRC) ariannamethod/ariannamethod.h
	$(CC) -O2 -Iariannamethod -c $(AML_SRC) -o ariannamethod/ariannamethod.o
	ar rcs $@ ariannamethod/ariannamethod.o

leo: leo.c $(AML_LIB)
	$(CC) leo.c $(CFLAGS) $(AML_FLAGS) -o leo $(AML_LIB)

run: leo
	./leo

# unit tests — test_leo.c #includes leo.c with LEO_NO_MAIN
test: tests/test_leo.c leo.c
	$(CC) -DLEO_NO_MAIN tests/test_leo.c $(CFLAGS) -o tests/test_leo
	./tests/test_leo

# address + undefined behaviour sanitizers on the smoke run
asan: leo.c
	$(CC) leo.c $(SANED) -o leo.asan
	./leo.asan

clean:
	rm -f leo leo.asan tests/test_leo *.state
