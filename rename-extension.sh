for f in *.markdown; do 
    mv -- "$f" "${f%.markdown}.md"
done
