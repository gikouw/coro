coro.o: coro.asm
	fasm coro.asm

example: coro.o example.c
	cc --static coro.o example.c -o example

clean:
	rm -f coro.o example
