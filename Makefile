CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -pedantic

leo: leo.c
	$(CC) $(CFLAGS) leo.c -lm -pthread -o leo

.PHONY: leo
