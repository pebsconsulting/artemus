PREFIX=/usr/local

all: artemus

artemus: artemus.pl artemus.src
	chmod 755 artemus
	perl -n -e '$$_=`cat $$1` if /^\@(\S*)\@$$/ ; print' < artemus.src > artemus
	chmod 555 artemus

install:
	install -o root -g root -m 755 artemus $(PREFIX)/bin
	install -o root -g root -m 755 littool $(PREFIX)/bin
	install -o root -g root -m 755 -d $(PREFIX)/share/artemus
	install -o root -g root -m 644 confs/* $(PREFIX)/share/artemus
	install -o root -g root -m 755 artemus-handler /var/www/cgi-bin

tags:
	ctags --language-force=perl artemus.pl artemus.src
