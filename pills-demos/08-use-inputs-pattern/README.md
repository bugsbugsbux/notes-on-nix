The graphviz test command is:

    echo 'graph test { a -- b }' | ./result/bin/dot -Tpng -o test.png

It shall fail if graphviz was built without png support.
