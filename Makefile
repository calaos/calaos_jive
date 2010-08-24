
ARCHIVE=Calaos.zip

SRC=CalaosApplet.lua CalaosMeta.lua install.xml
GFX=*.png

all: $(ARCHIVE)

$(ARCHIVE):
	(cd Calaos; zip ../$(ARCHIVE) $(SRC) $(GFX);)
