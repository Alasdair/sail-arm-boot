#include<inttypes.h>

/*
 * Special putchar function that outputs to TUBE memory address
 */
void tube_char(char c)
{
  asm volatile
    ("ldr x1, =0x13000000\n\t"
     "strb %w[c], [x1]"
     : /* No output */
     : [c] "r" (c)
     : "x1");
}

void tube_string(const char *str)
{
  int i = 0;
  while (str[i] != 0) {
    tube_char(str[i]);
    i++;
  }
}

void tube_uint64(const uint64_t n)
{
  tube_string("0x");

  uint64_t m = n;

  for (int i = 15; i >= 0; --i) {
    char c = (char) ((0xF & (m >> i * 4)) + 0x30);
    tube_char((c < 0x3A) ? c : c + 0x7);
  }
  tube_char('\n');
}

uint64_t get_currentel()
{
  uint64_t el;
  asm volatile
    ("mrs %x[r], currentel" : [r] "=r" (el));
  return el >> 2;
}

uint64_t get_tbclk()
{
  uint64_t cntfrq;
  asm volatile
    ("mrs %x[r], cntfrq_el0" : [r] "=r" (cntfrq));
  return cntfrq;
}

void main() {
  tube_string("Calling bootloader main()\n");
  tube_string("Exception level is ");
  tube_uint64(get_currentel());
  tube_char('\n');
  tube_string("Booting Kernel...\n");
}
