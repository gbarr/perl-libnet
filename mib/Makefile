
MIB_PL = ./mib.pl
MIB_TXT = mib.txt

PERL = perl

all :  $(MIB_PL)

$(MIB_PL) : parse $(MIB_TXT)
	parse $(MIB_TXT) $(MIB_PL)

parse : parse.c
	$(CC) parse.c -o parse

install :
	cp $(MIB_PL) ../Net/SNMP/$(MIB_PL)

dump : 
	$(PERL) dump_tree $(MIB_PL)

clean :
	rm -f core *.b[ac]k $(MIB_PL) parse
