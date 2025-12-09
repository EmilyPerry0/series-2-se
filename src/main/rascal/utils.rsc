module utils

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;

import IO;
import List;
import Set;
import String;
import ParseTree;

// ====================filtering functions built for this project====================
str removeLineComments(str line) {
    bool inString = false;
    bool escaped = false;
    
    for (int i <- [0..size(line)-1]) {
        if (escaped) {
            escaped = false;
            continue;
        }
        
        if (line[i] == "\\") {
            escaped = true;
            continue;
        }
        
        if (line[i] == "\"") {
            inString = !inString;
        }
        
        // Found // outside of a string
        if (!inString && i < size(line)-1 && line[i] == "/" && line[i+1] == "/") {
            return line[0..i];
        }
    }
    return line;
}

// might need to revise to look for escaped versions of the block comment indicators (like in a string)
str removeMultiLineComments(str file){
    return visit(file) {
        case /\/\*.*?\*\//s => ""
    };
}

str removeWhitespace(str line){
    return visit (line) {
                case /[\t\n]/ => ""
                };
}
// ====================class provided functions====================
list[Declaration] getASTs(loc projectLocation) {
    M3 model = createM3FromMavenProject(projectLocation);
    list[Declaration] asts = [createAstFromFile(f, true)
        | f <- files(model.containment), isCompilationUnit(f)];
    return asts;
}

// ====================reused functions from series 1====================
int countLOC(str source) {
    return (0 | it + 1 | /\n/ := source);
}