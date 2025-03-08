source rwtextool/venv/bin/activate

unzip data.zip "images/inv_town_decoration*" 
find images/inv_town_decoration*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
find images/*.* | xargs rm # remove tex and atlas files
find images/*/town_prop_* | xargs -I {} mv {} images/ # move all pngs out
find images/*/ -type d | xargs rm -r # remove remaining folders
