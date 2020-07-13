MEMORY
	{
	ram	: ORIGIN = 0x00000000, LENGTH = 0x00001000
	}

SECTIONS
{
    . = 0x80000000;
    .text :
	{
	*(.text)
	} > ram

    . = ALIGN(0x1000);
    .tohost : { *(.tohost) } > ram

	.data :
	{
	*(.data)
	} > ram

	.bss :
	{
	*(.bss)
	} > ram
}

ENTRY (_start)
