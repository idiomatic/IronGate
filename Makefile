# Copyright (c) 2012, r. brian harrison.  All rights reserved.

VERSION=0.8

APP=IronGate

FILES=	$(APP)/$(APP).toc \
	$(APP)/$(APP).lua \
	$(APP)/Locales/deDE.lua \
	$(APP)/Locales/enUS.lua \
	$(APP)/Locales/esES.lua \
	$(APP)/Locales/frFR.lua \
	$(APP)/Locales/koKR.lua \
	$(APP)/Locales/ptBR.lua \
	$(APP)/Locales/ruRU.lua \
	$(APP)/Locales/zhCN.lua \
	$(APP)/Locales/zhTW.lua \
	$(APP)/$(APP)_Version.lua

DIRS=	

build:
	sed -i~ -e "s/^\(## Title: [^|]* |cff00aa00\)[^|]*|r/\1$(VERSION)|r/" -e "s/^\(## Version: \)[0-9.-]*/\1$(VERSION)/" $(APP).toc
	(echo "$(APP) = $(APP) or { }"; \
	 echo "$(APP).VERSION = \"$(VERSION)\"" ) > $(APP)_Version.lua
	-rm ../$(APP)-$(VERSION).zip
	(cd .. && zip -r $(APP)-$(VERSION).zip $(FILES) $(DIRS))
