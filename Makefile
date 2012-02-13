# Copyright (c) 2012, r. brian harrison.  All rights reserved.

VERSION=0.1

APP=IronGate

FILES=	$(APP)/$(APP).toc \
	$(APP)/$(APP).lua \
	$(APP)/$(APP)_Version.lua

DIRS=	

build:
	sed -i.bak -e "s/^\(## Title: [^|]* |cff00aa00\)[^|]*|r/\1$(VERSION)|r/" -e "s/^\(## Version: \)[0-9.-]*/\1$(VERSION)/" $(APP).toc
	(echo "$(APP) = $(APP) or { }"; \
	 echo "$(APP).VERSION = \"$(VERSION)\"" ) > $(APP)_Version.lua
	-rm ../$(APP)-$(VERSION).zip
	(cd .. && zip -r $(APP)-$(VERSION).zip $(FILES) $(DIRS))
