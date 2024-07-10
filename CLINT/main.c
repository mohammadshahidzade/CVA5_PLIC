// This file is Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <irq.h>
#include <libbase/uart.h>
#include <libbase/console.h>
#include <generated/csr.h>

/*-----------------------------------------------------------------------*/
/* Uart                                                                  */
/*-----------------------------------------------------------------------*/

static char *readstr(void)
{
	char c[2];
	static char s[64];
	static int ptr = 0;

	if(readchar_nonblock()) {
		c[0] = getchar();
		c[1] = 0;
		switch(c[0]) {
			case 0x7f:
			case 0x08:
				if(ptr > 0) {
					ptr--;
					fputs("\x08 \x08", stdout);
				}
				break;
			case 0x07:
				break;
			case '\r':
			case '\n':
				s[ptr] = 0x00;
				fputs("\n", stdout);
				ptr = 0;
				return s;
			default:
				if(ptr >= (sizeof(s) - 1))
					break;
				fputs(c, stdout);
				s[ptr] = c[0];
				ptr++;
				break;
		}
	}

	return NULL;
}

static char *get_token(char **str)
{
	char *c, *d;

	c = (char *)strchr(*str, ' ');
	if(c == NULL) {
		d = *str;
		*str = *str+strlen(*str);
		return d;
	}
	*c = 0;
	d = *str;
	*str = c+1;
	return d;
}

static void prompt(void)
{
	printf("\e[92;1mlitex-demo-app\e[0m> ");
}

/*-----------------------------------------------------------------------*/
/* Help                                                                  */
/*-----------------------------------------------------------------------*/

static void help(void)
{
	puts("\nLiteX minimal demo app built "__DATE__" "__TIME__"\n");
	puts("Available commands:");
	puts("help               - Show this command");
	puts("reboot             - Reboot CPU");
#ifdef CSR_LEDS_BASE
	puts("led                - Led demo");
#endif
	puts("donut              - Spinning Donut demo");
	puts("helloc             - Hello C");
#ifdef WITH_CXX
	puts("hellocpp           - Hello C++");
#endif
}

/*-----------------------------------------------------------------------*/
/* Commands                                                              */
/*-----------------------------------------------------------------------*/

static void reboot_cmd(void)
{
	ctrl_reset_write(1);
}

#ifdef CSR_LEDS_BASE
static void led_cmd(void)
{
	int i;
	printf("Led demo...\n");

	printf("Counter mode...\n");
	for(i=0; i<32; i++) {
		leds_out_write(i);
		busy_wait(100);
	}

	printf("Shift mode...\n");
	for(i=0; i<4; i++) {
		leds_out_write(1<<i);
		busy_wait(200);
	}
	for(i=0; i<4; i++) {
		leds_out_write(1<<(3-i));
		busy_wait(200);
	}

	printf("Dance mode...\n");
	for(i=0; i<4; i++) {
		leds_out_write(0x55);
		busy_wait(200);
		leds_out_write(0xaa);
		busy_wait(200);
	}
}
#endif

extern void donut(void);

static void donut_cmd(void)
{
	printf("Donut demo...\n");
	donut();
}

extern void helloc(void);

static void helloc_cmd(void)
{
	printf("Hello C demo...\n");
	helloc();
}

#ifdef WITH_CXX
extern void hellocpp(void);

static void hellocpp_cmd(void)
{
	printf("Hello C++ demo...\n");
	hellocpp();
}
#endif

/*-----------------------------------------------------------------------*/
/* Console service / Main                                                */
/*-----------------------------------------------------------------------*/

static void console_service(void)
{
	char *str;
	char *token;

	str = readstr();
	if(str == NULL) return;
	token = get_token(&str);
	if(strcmp(token, "help") == 0)
		help();
	else if(strcmp(token, "reboot") == 0)
		reboot_cmd();
#ifdef CSR_LEDS_BASE
	else if(strcmp(token, "led") == 0)
		led_cmd();
#endif
	else if(strcmp(token, "donut") == 0)
		donut_cmd();
	else if(strcmp(token, "helloc") == 0)
		helloc_cmd();
#ifdef WITH_CXX
	else if(strcmp(token, "hellocpp") == 0)
		hellocpp_cmd();
#endif
	prompt();
}

int ret_func2(int x);
int ret_func1(int x){
	x = x+5;
	return ret_func2(x);
}


int ret_func2(int x){
	x = x+10;
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	asm volatile ("nop");
	return x;
}


uint32_t get_mtimecmp() {
    uint32_t value;
    // Inline assembly to load the address of mtimecmp into t1 and then load the value into 'value'
    __asm__ volatile (
        "la t1, 0xf0014000\n"   // Load the address of mtimecmp into t1
        "lw %0, 0(t1)\n"      // Load the value at the address in t1 into value
        : "=r" (value)          // Output operand
        :                       // No input operands
        : "t1"                  // Clobbered registers
    );
    return value;
}

uint32_t get_mtime() {
    uint32_t value;
    // Inline assembly to load the address of mtimecmp into t1 and then load the value into 'value'
    __asm__ volatile (
        "la t1, 0xf001bff8\n"   // Load the address of mtimecmp into t1
        "lw %0, 0(t1)\n"      // Load the value at the address in t1 into value
        : "=r" (value)          // Output operand
        :                       // No input operands
        : "t1"                  // Clobbered registers
    );
    return value;
}

void set_mtimecmp(uint32_t value) {
    // Inline assembly to load the address of mtimecmp into t1 and then store the value
    __asm__ volatile (
        "la t1, 0xf0014000\n"  // Load the address of mtimecmp into t1
        "sw %0, 0(t1)\n"       // Store the value at the address in t1
        :                      // No output operands
        : "r" (value)          // Input operand
        : "t1"                 // Clobbered registers
    );
}



void set_mtime(uint32_t value) {
    // Inline assembly to load the address of mtimecmp into t1 and then store the value
    __asm__ volatile (
        "la t1, 0xf001bff8\n"  // Load the address of mtimecmp into t1
        "sw %0, 0(t1)\n"       // Store the value at the address in t1
        :                      // No output operands
        : "r" (value)          // Input operand
        : "t1"                 // Clobbered registers
    );
}



int main(void)
{
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
	// csrhandler_state_write(5);//out offset state
#ifdef CONFIG_CPU_HAS_INTERRUPT
	irq_setmask(0);
	irq_setie(1);
#endif
	uart_init();

	for(int i=-200;i<-100;i++){
		set_mtimecmp(i);
		printf("mtimecmp: %d\n", get_mtimecmp());
	}
	for(int i=100;i<200;i++){
		set_mtime(i);
		printf("mtime: %d\n", get_mtime());
	}
	set_mtimecmp(10000);
	set_mtime(0);
	while(1){
		printf("waiting for inetrrupt\n");
	}
	// help();
	// prompt();

	// while(1) {
		// printf('11\n');
	// 	console_service();
	// }
	// for(int i=0;i<10;i++){
	// 	csrhandler_state_write(0);//out offset state
	// 	csrhandler_value_write((uint32_t) i);//out offset value
	// 	csrhandler_state_write(1);//out offset state
	// }

	// for(int i=0;i<10;i++){
	// 	csrhandler_state_write(0);//out offset state
	// 	csrhandler_value_write((uint32_t) (i+(int)'a'));//out offset value
	// 	csrhandler_state_write(2);//out offset state
	// }
	// for(int i=0;i<10;i++){
	// 	csrhandler_state_write(0);//out offset state
	// 	csrhandler_value_write((uint32_t) i);//out offset value
	// 	csrhandler_state_write(3);//out offset state
	// }
	// for(int i=0;i<10;i++){
	// 	csrhandler_state_write(0);//out offset state
	// 	csrhandler_value_write((uint32_t) i);//out offset value
	// 	csrhandler_state_write(4);//out offset state
	// }
	// irq_setmask(1);
	// int x = 0;
	// irq_setie(1);
	// while(1){
	// 	x+=1;
	// 	// ret_func1(5);
	// 	// x+=2;
	// // }
	// 	if(x==999999999){
	// 		printf("found you\n");
	// 		x = 0;
	// 	}
	// 	if(x==1000000000){
	// 		irq_setie(0);
	// 	}
	// 	for(int i=0;i<100000;i++){
    //     	asm volatile ("nop");
	// 	}
	// 	if(x==1000000000){
	// 		irq_setie(0);
	// 	}
	// }
	// irq_setie(0);
	// while(1) {
	// 	irq_setie(0);
	// 	printf(" ");
	// 	irq_setie(1);
	// }
	    asm volatile (
		"li t0, 156\n"
		"la t1, 0xf0014000\n"
		"sw t0, 0(t1)\n"
        // "li ra, 0x0000\n"    // Set ra to 0x0000
        // "li a0, 0x1111\n"    // Set a0 to 0x1111
        // "li a1, 0x2222\n"    // Set a1 to 0x2222
        // "li a2, 0x3333\n"    // Set a2 to 0x3333
        // "li a3, 0x4444\n"    // Set a3 to 0x4444
        // "li a4, 0x5555\n"    // Set a4 to 0x5555
        // "li a5, 0x6666\n"    // Set a5 to 0x6666
        // "li a6, 0x7777\n"    // Set a6 to 0x7777
        // "li a7, 0x8888\n"    // Set a7 to 0x8888
        // "li t0, 0x9999\n"    // Set t0 to 0x9999
        // "li t1, 0xAAAA\n"    // Set t1 to 0xAAAA
        // "li t2, 0xBBBB\n"    // Set t2 to 0xBBBB
        // "li t3, 0xCCCC\n"    // Set t3 to 0xCCCC
        // "li t4, 0xDDDD\n"    // Set t4 to 0xDDDD
        // "li t5, 0xEEEE\n"    // Set t5 to 0xEEEE
        // "li t6, 0xFFFF\n"    // Set t6 to 0xFFFF
    );
	// int a0 = 10;
    // int a1 = 0;
    // int a2 = 30;
    // int a3 = 40;
    // int a4, a5; // Temporary variables used in assembly
	// int sp;
    // Inline assembly to execute the provided instructions
	// asm volatile("");
	// while(1){

    // asm volatile (
	// 	// "li %1, 0xAAAAAAAA\n"    // Load the 1010 pattern into reg_a
    //     // "li t0, 0xAAAAAAAA\n"          // Load the 1010 pattern into temporary register t0
    //     // "beq %1, t0, skip_asm\n"       // If reg_a == t0, branch to label 1
    //     // Check if a1 is zero
    //     "beqz %1, skip_asm\n"   // If a1 is zero, skip the assembly block
    //     // Instructions for the first block (strnlen)
    //     "add %0, %2, %1\n"       // 40000164: add a1, a0, a1
    //     "mv %3, %2\n"            // 40000168: mv a5, a0
    //     "bne %3, %1, 1f\n"       // 4000016c: bne a5, a1, 40000178
    //     "sub %2, %3, %2\n"       // 40000170: sub a0, a5, a0
    //     "ret\n"                  // 40000174: ret
    //     "1:\n"                   // Label 1

    //     // Instructions for the second block (printf)
    //     "addi sp, sp, -64\n"     // 40000188: addi sp, sp, -64
    //     "sw %4, 52(sp)\n"        // 4000018c: sw a5, 52(sp)
    //     "lui %4, 0x40001\n"      // 40000190: lui a5, 0x40001
    //     "sw %1, 36(sp)\n"        // 40000194: sw a1, 36(sp)
    //     "mv %1, %0\n"            // 40000198: mv a1, a0
    //     "lw %0, 960(a5)\n"       // 4000019c: lw a0, 960(a5)
    //     "sw %2, 40(sp)\n"        // 400001a0: sw a2, 40(sp)
    //     "addi %2, sp, 36\n"      // 400001a4: addi a2, sp, 36
    //     "sw ra, 28(sp)\n"        // 400001a8: sw ra, 28(sp)
    //     "sw %3, 44(sp)\n"        // 400001ac: sw a3, 44(sp)
    //     "skip_asm:\n"            // Label to skip the assembly block
    //     :
    //     : "r"(a0), "r"(a1), "r"(a2), "r"(a3), "r"(a5)
    //     : // clobbered registers
    // );
	// }
	// ret_func1(0);
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
        // asm volatile ("nop");
	return 0;
}
