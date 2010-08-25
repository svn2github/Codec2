/*---------------------------------------------------------------------------*\

  FILE........: c2dec.c
  AUTHOR......: David Rowe
  DATE CREATED: 23/8/2010

  Decodes a file of bits to a file of raw speech samples using codec2. Demo
  program for codec2.

\*---------------------------------------------------------------------------*/

/*
  Copyright (C) 2010 David Rowe

  All rights reserved.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License version 2.1, as
  published by the Free Software Foundation.  This program is
  distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include "codec2.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    void *codec2;
    FILE *fin;
    FILE *fout;
    short buf[CODEC2_SAMPLES_PER_FRAME];
    char  bits[CODEC2_BITS_PER_FRAME];
    int   i;

    if (argc != 3) {
	printf("usage: %s InputBitFile OutputRawSpeechFile\n", argv[0]);
	exit(0);
    }
 
    fin = fopen(argv[1],"rb");
    if (fin == NULL) {
	printf("Error opening input bit file: %s\n", argv[1]);
	exit(0);
    }

    fout = fopen(argv[2],"wb");
    if (fout == NULL) {
	printf("Error opening output speech file: %s\n", argv[2]);
	exit(0);
    }

    codec2 = codec2_create();

    while(fread(bits, sizeof(char), CODEC2_BITS_PER_FRAME, fin) ==
	  CODEC2_BITS_PER_FRAME) {
	//for(i=0; i<CODEC2_BITS_PER_FRAME; i++)
	//    printf("bit[%d] = %d\n", i, bits[i]);
	codec2_decode(codec2, buf, bits);
	fwrite(buf, sizeof(short), CODEC2_SAMPLES_PER_FRAME, fout);
    }

    codec2_destroy(codec2);

    fclose(fin);
    fclose(fout);

    return 0;
}