source rwtextool/venv/bin/activate

unzip data.zip "images/ui_ftf_mastery_icons*" 
find images/ui_ftf_mastery_icons*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
find images/*.* | xargs rm # remove tex and atlas files
find images/ui_ftf_mastery_icons*/* | xargs -I {} mv {} images/ # move all pngs out
find images/*/ -type d | xargs rm -r # remove remaining folders
