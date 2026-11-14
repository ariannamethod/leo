CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -pedantic

leo: leo.c
	$(CC) $(CFLAGS) leo.c -lm -pthread -o leo

.PHONY: leo court

court: court.c leo.c
	$(CC) $(CFLAGS) court.c -lm -pthread -o court

neoleo: neoleo.c leo.c
	$(CC) $(CFLAGS) neoleo.c -lm -pthread -o neoleo

.PHONY: neoleo test-neoleo

test-neoleo: tests/neoleo_test.c neoleo.c leo.c
	$(CC) $(CFLAGS) tests/neoleo_test.c -lm -pthread -o neoleo-test
	./neoleo-test
