source rwtextool/venv/bin/activate

unzip data.zip "images/icons_ftf.*" 
python rwtextool/src/tex2img.py -A images/icons_ftf.tex
find images/*.* | xargs rm # remove tex and atlas files
mv images/icons_ftf/item_temp.png images/ # move png out
find images/*/ -type d | xargs rm -r # remove remaining folders
