source rwtextool/venv/bin/activate

unzip data.zip "images/map_ftf.*" 
find images/*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
find images/*.* | xargs rm # remove tex and atlas files
find images/*/* | xargs -I {} mv {} images/ # move all pngs out
find images/*/ -type d | xargs rm -r # remove remaining folders
