#include <stdio.h>

#define C64(x) ((U64)(x##ULL))
typedef unsigned long long U64;

/*U64 diagonalMask(int sq) {*/
/*   const U64 maindia = C64(0x8040201008040201);*/
/*   int diag =8*(sq & 7) - (sq & 56);*/
/*   int nort = -diag & ( diag >> 31);*/
/*   int sout =  diag & (-diag >> 31);*/
/*   return (maindia >> sout) << nort;*/
/*}*/

U64 diagonalMask(int sq) {
   const U64 maindia = C64(0x8040201008040201);
   int diag  = (sq&7) - (sq>>3);
   printf("diag: %d\n", diag);
   return diag >= 0 ? maindia >> diag*8 : maindia << -diag*8;
}

U64 antiDiagMask(int sq) {
   const U64 maindia = C64(0x0102040810204080);
   int diag  = 7 - (sq&7) - (sq>>3);
   return diag >= 0 ? maindia >> diag*8 : maindia << -diag*8;
}

U64 diagonalMaskEx(int sq) {return (C64(1) << sq) ^ diagonalMask(sq);}
U64 antiDiagMaskEx(int sq) {return (C64(1) << sq) ^ antiDiagMask(sq);}

void printBitboard(U64 bb) {
   for (int i = 0; i < 64; i++) {
      if (bb & (C64(1) << i)) {
	 printf("1 ");
      } else {
	 printf("0 ");
      }
      if ((i + 1) % 8 == 0) {
	 printf("\n");
      }
   }
}

int main(void) {

	U64 bb = antiDiagMaskEx(56);
	printBitboard(bb);

	return 0;
}
