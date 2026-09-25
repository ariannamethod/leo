CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -pedantic

leo: leo.c
	$(CC) $(CFLAGS) leo.c -lm -pthread -o leo

.PHONY: leo court

court: court.c leo.c
	$(CC) $(CFLAGS) court.c -lm -pthread -o court
