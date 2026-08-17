CC = cc
CFLAGS = -std=c11 -Wall -Wextra -pthread -I../src -DPRIMITIVES_TESTING
LDFLAGS = -lpthread

TEST_BIN = test_primitives_init
TEST_SRC = test_primitives_init.c
IMPL_SRC = ../src/primitives_init.c

.PHONY: all test clean

all: $(TEST_BIN)

$(TEST_BIN): $(TEST_SRC) $(IMPL_SRC) ../src/primitives_init.h
	$(CC) $(CFLAGS) -o $@ $(TEST_SRC) $(IMPL_SRC) $(LDFLAGS)

test: $(TEST_BIN)
	./$(TEST_BIN)

clean:
	rm -f $(TEST_BIN)
