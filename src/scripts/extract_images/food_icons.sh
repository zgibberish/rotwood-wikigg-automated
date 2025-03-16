source rwtextool/venv/bin/activate

unzip data.zip "images/icons_inventory*" 
find images/icons_inventory*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
find images/*.* | xargs rm # remove tex and atlas files
for filename in $(find images/*/*food_cooked*); do
    # move all images out to images/, but
    # replace slashes in file path to underscores
    # and use that as the file names
    new_filename="$(echo "$filename" | tr / _)"
    mv $filename "images/$new_filename"
done
find images/*/ -type d | xargs rm -r # remove remaining folders
