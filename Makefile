AS := nasm
ASFLAGS += -felf64

BUILDDIR := build

BIN    := sweeper
SRC    := $(wildcard *.asm)
OBJ    := ${SRC:%.asm=${BUILDDIR}/%.o}
DEP    := ${OBJ:.o=.d}

.PHONY: all clean

all: ${BIN}

${BIN}: ${OBJ}
	$(LD) -o $@ $(LDFLAGS) $^

${BUILDDIR}/%.o: %.asm
	@mkdir -p ${@D}
	@$(AS) -o $@ -M -MF ${@:.o=.d} $<
	$(AS) -o $@ $(ASFLAGS) $<


clean:
	rm -rf ${BUILDDIR} ${BIN}

-include ${DEP}
