   .org 0x0
   .set noat
   .set noreorder
   .set nomacro
   .global _start
_start:
   ori $1,$0,0xf
   mtc0 $1,$11,0x0  #写compare寄存器，开始计时
   lui $1,0x1000
   ori $1,$1,0x401
   mtc0 $1,$12,0x0  #将0x401写如status寄存器
   mfc0 $2,$12,0x0  #读status寄存器，$2=0x401

_loop:
   j _loop
   nop
   
   
