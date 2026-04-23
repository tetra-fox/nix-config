import sys
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.ttLib import TTFont

font = TTFont(sys.argv[1])
instantiateVariableFont(font, {"FILL": 1.0}, inplace=True)

for rec in font["name"].names:
    if rec.nameID in (1, 4, 6):  # family, full, postscript
        val = rec.toUnicode()
        rec.string = val.replace("Rounded", "Rounded Filled")

font.save(sys.argv[2])
