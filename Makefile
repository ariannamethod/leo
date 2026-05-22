CC      ?= cc
CFLAGS  ?= -O2 -lm -Wall -Wextra
SANED    = -O1 -g -fsanitize=address,undefined -lm -Wall -Wextra

.PHONY: all test asan clean run

all: leo

leo: leo.c
	$(CC) leo.c $(CFLAGS) -o leo

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
