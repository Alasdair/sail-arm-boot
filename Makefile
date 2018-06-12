CC=aarch64-linux-gnu-gcc
OBJCOPY=aarch64-linux-gnu-objcopy
AS=aarch64-linux-gnu-as
LD=aarch64-linux-gnu-ld

default: bootloader.bin

%.o: %.S
	$(CC) -nostdlib -c $<

%.o: %.c
	$(CC) -nostdlib -fno-builtin -c $<

%.dtb: %.dts
	dtc -O dtb $< -o $@

bootloader: start.o bootloader.o bootloader.ld
	$(LD) -T bootloader.ld -verbose

bootloader.bin: bootloader
	$(OBJCOPY) -O binary bootloader bootloader.bin

clean:
	rm -f bootloader
	rm -f *.o
	rm -f *.bin
	rm -f *.dtb