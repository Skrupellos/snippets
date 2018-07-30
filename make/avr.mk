MCU            = m328p
F_CPU          = 16000000
FLASH_PORT    ?= /dev/ttyUSB0
FLASH         := -P $(FLASH_PORT) -b 57600 -c arduino

.DEFAULT_GOAL  = main.all
CC             = avr-gcc
CFLAGS         = -std=gnu11
CPPFLAGS       = -Werror -Wall -Wpedantic -Wextra \
                 -DF_CPU=$(F_CPU) -O0 \
                 -save-temps=obj -Wa,-adhln="$(@:.o=).lst" -MMD -MP
TARGET_ARCH   := -mmcu=$(MCU)
LDFLAGS        = -Wl,-Map="$@.map",--cref
SRC           := $(wildcard *.c)

.PHONY: flash clean distclean new
.PRECIOUS: %.hex %.eep



## LINK DEPENDENCIES
$(.DEFAULT_GOAL:%.all=%): $(SRC:%.c=%.o)


## COMPILE DEPENDENCIES
%.d:
	$(COMPILE.c) -MM -MF $@ $(@:%.d=%.c)

-include $(SRC:%.c=%.d)


## BUILD EXECUTABLE
%.hex: %
	avr-objcopy --output-target=ihex --remove-section=.eeprom \
	            "$<" "$@"

%.eep: %
	avr-objcopy --output-target=ihex --only-section=.eeprom \
	            --set-section-flags=.eeprom="alloc,load" \
	            --change-section-lma .eeprom=0 \
	            "$<" "$@"

.PHONY:
%.all: % %.hex %.eep
	@echo -e "\033[1m"
	@avr-size --format=avr --mcu=$(MCU) "$<"
	@avr-nm --size-sort --print-size --radix=d "$<"
	@echo -e "\033[0m"


## FLASH
.PHONY:
flash-%: %.all
	avrdude -p $(MCU) $(FLASH) -V \
	        -U "flash:w:$(<:.all=.hex)" \
	        -U "eeprom:w:$(<:.all=.eep)"

flash: $(.DEFAULT_GOAL:%.all=flash-%)


## JANITOR
clean:
	rm -fv $(.DEFAULT_GOAL:%.all=%){,.map} *.{i,lst,o,s,d}

distclean: clean
	rm -fv $(.DEFAULT_GOAL:%.all=%).{hex,eep}

new: distclean
	$(MAKE)
