#include <stdio.h>
#include <stdbool.h>

void coroutine_register(void (*func)(void));
void yield(void);

void func1(void) {
    for (int i = 0; i < 8; i++) {
        printf("[%d] hello from fn 1\n", i);
        yield();
    }
}

void func3(void) {
    for (int i = 0; i < 8; i++) {
        printf("[%d] hello from fn 3\n", i);
        yield();
    }
}

void func2(void) {
    for (int i = 0; i < 5; i++) {
        printf("[%d] hello from fn 2\n", i);
        yield();
    } 
}

int main(void)
{
    printf("start");
    coroutine_register(func1);
    coroutine_register(func2);
    coroutine_register(func3);

    for (int i = 1 ; i < 19; i++){
        printf("hello from main\n");
        yield(); 
    }
    printf("end\n"); 
}


