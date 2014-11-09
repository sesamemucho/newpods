prefix ?= /usr/local

dist_source := COPYING INSTALL Makefile README.rst newpods test_regexps.sh

version	:= $(shell ./newpods -Qv | sed -e 's/Newpods, version //')

all: newpods.7.gz

newpods.7.gz:
	sed -ne '/^: ...END_OF_MAN_PAGE./,$$p' < newpods | sed -e '/END_OF_MAN_PAGE/d' | gzip -9 >$@

html:
	rst2html README.rst >newpods.html

install: newpods.7.gz
	mkdir -p $(DESTDIR)$(prefix)/bin/
	install --mode 755 newpods $(DESTDIR)$(prefix)/bin/newpods

	mkdir -p $(DESTDIR)$(prefix)/share/man/man7/
	install --mode 644 newpods.7.gz $(DESTDIR)$(prefix)/share/man/man7/newpods.7.gz

dist: distclean
	tar czf newpods-$(version).tar.gz --transform "s,^\./,newpods-$(version)/," $(addprefix ./,$(dist_source))
	cp newpods newpods-$(version).sh

distclean: clean
	rm -f newpods-*.tar.gz
	rm -f newpods-*.sh

clean:
	rm -f newpods.7.gz
	rm -f newpods.7
	rm -f newpods.hmtl

dist-man:
	rm -f newpods.7
	rst2man README.rst >newpods.7
# Then embed newpods.7 into the newpods script.
