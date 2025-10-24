format ELF64 

;TODO: maybe this can be possible with just singly linked list  

macro push_regs_and_save_stack coro_ptr {
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov [coro_ptr + Coro_offset_rbp], rbp
    mov [coro_ptr + Coro_offset_rsp], rsp
}

macro restore_stack_and_pop_regs coro_ptr {
    mov rbp, [coro_ptr + Coro_offset_rbp]
    mov rsp, [coro_ptr + Coro_offset_rsp]
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
}

section '.text' executable 

public coroutine_register
public yield

Coro_offset_rsp        = 0
Coro_offset_rbp        = 8
Coro_offset_next       = 16
Coro_offset_prev       = 24
Coro_offset_stack_leftmost = 32
Coro_size              = 40
STACK_SIZE = (1*1024*1024)

alloc:                      ; rdi = size
    mov rax, 9               ; sys_mmap
    xor rsi, rsi
    mov rsi, rdi             ; length = size
    xor rdi, rdi             ; addr = NULL
    mov rdx, 3               ; PROT_READ | PROT_WRITE
    mov r10, 0x22            ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall
    ret

alloc_stack:                ; rdi = size
    mov rax, 9               ; sys_mmap
    xor rsi, rsi
    mov rsi, rdi             ; length = size
    xor rdi, rdi             ; addr = NULL
    mov rdx, 3               ; PROT_READ | PROT_WRITE
    mov r10, 0x122           ; MAP_PRIVATE | MAP_ANONYMOUS | MAP_GROWSDOWN
    mov r8, -1
    xor r9, r9
    syscall
    ret


init_main_coro:
    mov rdi, Coro_size
    call alloc           
    mov rdi, rax 

    mov [rdi + Coro_offset_rsp], rsp
    mov [rdi + Coro_offset_rbp], rbp

    mov qword [rdi + Coro_offset_stack_leftmost], 0 ;redundant. main_coro will never use this 

    mov [rdi + Coro_offset_next], rdi
    mov [rdi + Coro_offset_prev], rdi

    mov [current], rdi
    mov byte [is_main_initialized], 1
    ret

; rdi = function addr
coroutine_register:

    cmp byte [is_main_initialized], 0
    jnz .continue 
    push rdi
    call init_main_coro 
    pop rdi
.continue:

    push r12                            ;save before using

    push rdi                            ;save fn addr

    mov rdi, Coro_size
    call alloc
    mov r12, rax                        ;new coro addr

    mov rdi, STACK_SIZE
    call alloc_stack
    mov [r12 + Coro_offset_stack_leftmost], rax
    add rax, STACK_SIZE                 ;stacks rsp (rightmost)

    pop rdi ;recover before switch

    mov r11, rsp                        ;save caller’s rsp

    mov rsp, rax                        ;switch to coroutine’s stack
    ;---------------regsitering-coro-stack------------------
    push implicit_yield             ;return address when entry function finishes
    push rdi                        ;jmp back addr for yield on ret when *becoming the switch target for first time* 
                                    ;as yield expects it, it will be pushed by calling yield() for next turn

    sub rsp, 40                     ;similar reason^

    mov [r12 + Coro_offset_rsp], rsp
    mov [r12 + Coro_offset_rbp], rbp   
    
    mov rsp, r11                    ;restore caller's rsp
    ;-------------------------------------------------------

    mov rax, [current]            
    mov rcx, [rax + Coro_offset_next]

    mov [r12 + Coro_offset_prev], rax
    mov [r12 + Coro_offset_next], rcx
    mov [rax + Coro_offset_next], r12
    mov [rcx + Coro_offset_prev], r12

    ;TODO: write the reason for not updating "current" here

    pop r12                         ;restore for the caller 
    ret

yield:                                  ;expects already restored stack 

    cmp byte [is_main_initialized], 0
    jnz .continue 
    call init_main_coro 
.continue:


    mov rax, [current]
    push_regs_and_save_stack rax

    mov rax, [rax + Coro_offset_next]
    mov [current], rax

    restore_stack_and_pop_regs rax
    ret

macro free_stack addr {                  
    mov rdi, addr
    mov     rsi, STACK_SIZE
    mov     rax, 11          ; sys_munmap
    syscall
}

macro free_coro addr {                         
    mov rdi,  addr
    mov rsi, Coro_size
    mov     rax, 11 
    syscall
}

implicit_yield:
    mov rax, [current]

    mov rcx, [rax + Coro_offset_prev]    ; current_prev
    mov rdx, [rax + Coro_offset_next]    ; current_next

    ;unlinking current 
    mov [rcx + Coro_offset_next], rdx    ; current_prev_next = current_next
    mov [rdx + Coro_offset_prev], rcx    ; current_next_prev = current_prex
    
    mov [current], rdx                   ;new current

    free_stack [rax + Coro_offset_stack_leftmost]
    free_coro rax

    restore_stack_and_pop_regs rdx
    ret

section '.data' writeable 
is_main_initialized db 0

section '.bss' writable 
current rq 1
