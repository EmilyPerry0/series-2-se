module type_2_baxter

/*
TODOs:
-Add sequencing
-Edit the subsumption logic so that it doesn't care about comments
-Edit the clone counting code
-edit the line counting code (based off of the clone classes instead probably)
*/

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;
import lang::json::IO;


import IO;
import List;
import String;
import Node;
import Set;
import Relation;
import analysis::graphs::Graph;
import Location;

import utils;

/*
The algorithm consists of the following steps:
1. parse program and generate AST
2. serialize AST
3. apply suffix tree detection
4. decompose resulting type-1/type-2 token sequence into complete syntactic units
*/

int main(){
    int cloneType = 2;
    str projectName = "smallSQL";
    // str projectName = "HSQL";

    loc smallsql_loc = |cwd:///smallsql0.21_src/|;
    // loc hsql_loc = |cwd:///hsqldb-2.3.1/|;
    loc benchmarkProject_loc = |cwd:///benchmarkProject/|;

    list[Declaration] asts = getASTs(smallsql_loc); // step1: parse program and generate AST
    // loc test1 = |cwd:///benchmarkProject/src/benchmarkProject/OrderProcessor.java|(2008,63,<53,8>,<55,9>);
    // loc test2 = |cwd:///benchmarkProject/src/benchmarkProject/OrderProcessor.java|(1705,402,<48,4>,<57,5>);
    // println(isContainedIn(test1, test2));

    int massThreshVal = 20; // it's now 15, could go lower?
    real simThresh = 1.0;

    list[ClonePair] allPairs = toList(baxtersAlgo(asts, massThreshVal, simThresh, cloneType));
    set[set[loc]] cloneClasses = removeSubsumedClones(generateCloneClasses(toSet(allPairs)));
    // set[set[loc]] cloneClasses = generateCloneClasses(toSet(allPairs));

    int clonedLOC = getTotalLOCFromAllClones(cloneClasses);
    int totalLOC = getProjectLOCFromASTs(asts);
    real duplicatedPercent = 100.0 * clonedLOC / totalLOC;
    int biggestCloneSize = getBiggestCloneSize(cloneClasses);
    int biggestCloneClass = getBiggestCloneClass(cloneClasses);

    // --- JSON Output Start ---
    map[str, value] jsonOutput = generateJsonOutput(projectName, cloneType, cloneClasses, asts);
    
    // Convert the Rascal map structure to a JSON string
    
    // Write the JSON string to a file (e.g., "clone_report.json")
    writeJSON(|cwd:///data/clone_report.json|, jsonOutput);
    
    println("Clone report written to clone_report.json");
    // --- JSON Output End ---

    println("Summary Report:");
    println("Project: <projectName>");
    println("Clone Type <cloneType>");
    println("Duplicated Line %: <duplicatedPercent>%");
    println("Number of Clones: <size(allPairs)>");
    println("Biggest Clone: <biggestCloneSize> LOC");
    println("Biggest Clone Class: <biggestCloneClass> Members");
    println("Some Example Clones: ");
    for(i <- [0,1]){
        println("=====Example <i+1>=====");
        println("Location 1: <allPairs[i].first_file>");
        println("Location 2: <allPairs[i].second_file>");
        println("File 1:");
        loc first_file_example = allPairs[i].first_file;
        str first_str_example = readFile(first_file_example);
        println(first_str_example);
        println("File 2:");
        loc second_file_example = allPairs[i].second_file;
        str second_str_example = readFile(second_file_example);
        println(second_str_example);
    }
    int i = 0;
    for(cloneClass <- cloneClasses){
        println("Clone Class <i+1>: ");
        for(clone <- cloneClass){
            println("<clone>");
        }
        i += 1;
    }
    return 0;
}

/*
Baxter's algo for ASTs
1. Clones=∅
2. For each subtree i:
If mass(i)>=MassThreshold
Then hash i to bucket
3. For each subtree i and j in the same bucket
If CompareTree(i,j) > SimilarityThreshold
Then { For each subtree s of i
If IsMember(Clones,s)
Then RemoveClonePair(Clones,s)
For each subtree s of j
If IsMember(Clones,s)
Then RemoveClonePair(Clones,s)
AddClonePair(Clones,i,j)
}
*/

set[ClonePair] baxtersAlgo(list[Declaration] asts, int massThresh, real simThresh, int cloneType){
    set[ClonePair] allClonePairs = {};
    
    map[str, list[tuple[loc, node]]] hash_buckets = ();
    list[str] allHashVals = [];

    
        
    for(ast <- asts){
        Declaration newAST = ast;
        if(cloneType == 2){
            newAST = type2CloneASTFiltering(ast);
        }
        visit(newAST){
            case node subtree : {
                if(calcMass(subtree) >= massThresh){
                    //hash  i 
                    // might need to switch to a worse hash function if we want to detect similar but not exactly the same clones
                    // accoridng to the baxter paper, we might also want to make it so there are only size(asts) * 0.1 buckets
                    str hashVal = md5Hash(unsetRec(type2CloneASTFiltering(subtree), {"src", "decl", "typ"}));
                    if(hashVal in hash_buckets){
                        hash_buckets = hash_buckets + (hashVal:hash_buckets[hashVal] + [<subtree.src, subtree>]);
                    }else{
                        hash_buckets = hash_buckets + (hashVal:[<subtree.src, subtree>]);
                        allHashVals = allHashVals + hashVal;
                    }
                }
            }
        }
    }


    list[tuple[loc, node]] currBucket;
    list[str] sortedHashVals = allHashVals;
    sortedHashVals = sort(sortedHashVals, bool(str a, str b) {
        return calcMass(hash_buckets[a][0][1]) < calcMass(hash_buckets[b][0][1]);
    });


    for(str hashVal <- allHashVals){
        currBucket = hash_buckets[hashVal];
        for(i <- currBucket){
            for(j <- currBucket){
                if(i[0] != j[0] && compareTree(i[1],j[1]) >= simThresh){
                    allClonePairs = allClonePairs + {clonePair(i[0], j[0])};
                }
            }
        }
    }
    // set[ClonePair] trimmed_clones = removeSubsumedClones(allClonePairs);
    // for(str hashVal <- allHashVals){
    //     currBucket = hash_buckets[hashVal];
    //     for(i <- currBucket){
    //         for(j <- currBucket){
    //             // disregard when talking about the exact same piece of code
    //             // check Similarity
    //             if(i[0] != j[0] && compareTree(i[1],j[1]) > simThresh){
    //                 //For each subtree s of i
    //                 visit(i[1]){
    //                     case node subtree_i:{
    //                         //If IsMember(Clones,s)
    //                         if(isMember(allClonePairs, subtree_i)){
    //                             allClonePairs = {n | ClonePair n <- allClonePairs, n.first_file != subtree_i.src && n.second_file != subtree_i.src};
    //                         }
    //                     } 
    //                 }
    //                 //For each subtree s of i
    //                 visit(j[1]){
    //                     case node subtree_j:{
    //                         //If IsMember(Clones,s)
    //                         if(isMember(allClonePairs, subtree_j)){
    //                             allClonePairs = {n | ClonePair n <- allClonePairs, n.first_file != subtree_j.src && n.second_file != subtree_j.src};
    //                         }
    //                     } 
    //                 }
    //                 allClonePairs = allClonePairs + {clonePair(i[0], j[0])};
    //             }
    //         }
    //     }
    // }
    // set[ClonePair] trimmedClonePairs = removeSubsumedClones(allClonePairs);
    return allClonePairs;
}

// def will need to justify this in the report
int calcMass(node astNode){

    // ensures we only allow full lines
    loc sourceLoc = |http://www.example.org|;
    try 
        sourceLoc = astNode.src;
    catch:
        return -1;

    int result = 0;
    visit(astNode) {
        case node n: result += 1;
    }
    return result;
}


/*
Similarity = 2 x S / (2 x S + L + R)
where:
S = number of shared nodes
L = number of different nodes in sub-tree 1
R = number of different nodes in sub-tree 2
*/
real compareTree(node i, node j){
    node stripped_i = unsetRec(i, {"src", "decl", "typ"});
    node stripped_j = unsetRec(j, {"src", "decl", "typ"});

    // Get all nodes from both trees
    list[node] nodes_i = collectNodes(stripped_i);
    list[node] nodes_j = collectNodes(stripped_j);
    
    // Calculate shared and different nodes
    list[node] shared = nodes_i & nodes_j;  
    list[node] only_i = nodes_i - nodes_j;  
    list[node] only_j = nodes_j - nodes_i;  
    
    int S = size(shared);
    int L = size(only_i);
    int R = size(only_j);

    return 2.0 * S / (2.0 * S + L + R);
}

list[node] collectNodes(node tree) {
    list[node] result = [tree];
    visit(tree) {
        case node n: result += [n];
    }
    return result;
}

bool isMember(set[ClonePair] allClonePairs, node s){
    for(clonePair <- allClonePairs){
            switch (s){
                case Declaration d:{
                    if(d.src >= clonePair.first_file || d.src >= clonePair.second_file){
                        return true;
                    }
                }
            }
    }
    return false;
}

// set[set[loc]] removeSubsumedCloneClasses(set[set[loc]] cloneClasses){
//     set[set[loc]] resultingCloneClass = {}; 
//     for(cloneClass <- cloneClasses){
//         bool isSubsumedFlag = false;
//         for(compareCloneClass <- cloneClasses){
//             if(cloneClass == compareCloneClass){continue;}

//             if(isSubsumed(cloneClass, compareCloneClass)){
//                 isSubsumedFlag = true;
//             }
//         }
//         if(!isSubsumedFlag){
//             resultingCloneClass = resultingCloneClass + {cloneClass};
//         }
//     }
//     return resultingCloneClass;
// }

bool cloneClassSubsumed(set[loc] first_class, set[loc] second_class){
    bool contained = false;
    for(n <- first_class){
        contained = false;
        for(m <- second_class){
            if(isStrictlyContainedIn(n,m)){
                contained = true;
                continue;
            }
        }
        if(!contained){
            return false;
        }
    }
    return true;
}

set[set[loc]] removeSubsumedClones(set[set[loc]] allCloneClasses){
    // idea: loop through all of the clone pairs
    // if a clone pair's first file or second file is completely contained in another pair's first or second file, don't add it to the final set.
    set[set[loc]] cleanedCloneClasses = {};
    bool shouldAdd = true;
    for(cloneClass <- allCloneClasses){
        shouldAdd = true;
        for(compareClass <- allCloneClasses){
            if(cloneClass == compareClass) continue;
            // if((pair.first_file <= comparePair.first_file && pair.second_file <= comparePair.second_file)){
            //     shouldAdd = false;
            //     println("ddddfirst: <pair.first_file>");
            //     println("second: <comparePair.first_file>");
            //     println("first<pair.second_file>");
            //     println("second <comparePair.second_file>");
            // }
            // if( (pair.second_file < comparePair.first_file && pair.first_file < comparePair.second_file)){
            //     println("-");
            // }
            if(cloneClassSubsumed(cloneClass, compareClass)){
                shouldAdd = false;
            }
        }
        if(shouldAdd){
            cleanedCloneClasses = cleanedCloneClasses + {cloneClass};
        }
    }
    return cleanedCloneClasses;
}

set[set[loc]] generateCloneClasses(set[ClonePair] allPairs){
    
    set[loc] nodes = {p.first_file | ClonePair p <- allPairs} 
                   + {p.second_file | ClonePair p <- allPairs};
    
    rel[loc, loc] edges = {<p.first_file, p.second_file> | ClonePair p <- allPairs};
    rel[loc, loc] undirectedEdges = edges + invert(edges);
    set[set[loc]] cloneClasses = connectedComponents(undirectedEdges); 
    
    return cloneClasses;
}

// loc getFirstTokenLocation(node n) {
//     loc firstLoc = |unknown:///|; 
    
//     // Use a variable to track if we've found it to stop the search externally.
//     bool found = false; 

//     visit(n) {
//         case node sub: {
//             if (has(sub.src)) {
//                 firstLoc = sub.src;
//                 found = true;
//                 // To stop the traversal fully, you often need to use a 'throw' 
//                 // in Rascal, but for simplicity, we rely on the pre-order guarantee 
//                 // and break the loop logic if possible, or trust the pre-order finding.
//             }
//         }
//     }
//     // Since Rascal's 'visit' is pre-order, the last assignment to firstLoc 
//     // will be the result of the top-most/left-most node, which is what we want.
//     // The previous implementation was slightly confusing but functional due to pre-order. 
//     // We remove the return continue to be safer.
//     return firstLoc;
// }

// loc getLastTokenLocation(node n) {
//     loc lastLoc = |unknown:///|;

//     visit(n) {
//         case node sub: {
//             if (has(sub.src)) {
//                 // Check if this location ends AFTER our current lastLoc (or if lastLoc is still uninitialized)
//                 if (!has(lastLoc) || sub.src.end.line > lastLoc.end.line || 
//                    (sub.src.end.line == lastLoc.end.line && sub.src.end.column > lastLoc.end.column)) {
                    
//                     lastLoc = sub.src;
//                 }
//             }
//         }
//     }
//     return lastLoc;
// }

// Declaration stripLocation(Declaration d) {
//     if (!has(d.src)) return d;

//     loc oldLoc = d.src;
    
//     loc firstTokenLoc = getFirstTokenLocation(d);
//     loc lastTokenLoc = getLastTokenLocation(d);

//     if (has(firstTokenLoc) && has(lastTokenLoc)) {
//         loc newLoc = oldLoc.top[
//             begin: firstTokenLoc.begin, 
//             end: lastTokenLoc.end
//         ];
        
//         return setField(d, "src", newLoc);
//     }
    
//     return d;
// }

/**
 * Finds the nearest enclosing Class/Interface and Method/Constructor declaration 
 * for a given location (loc) within the ASTs.
 */
tuple[str, str] getEnclosingContext(loc cloneLoc, list[Declaration] allASTs) {
    str className = "UnknownClass";
    str methodName = "UnknownMethod";

    // 1. Find the specific AST for the file containing the clone
    Declaration fileAST = getFileAST(cloneLoc.path, allASTs);

    // 2. Traverse the file's AST to find the tightest enclosing declarations
    visit (fileAST) {
        // A. Catch Class or Interface declarations
        case Declaration td: {
            if (isStrictlyContainedIn(cloneLoc, td.src)) {
                // Keep updating the className to the innermost one found so far
                if (td has decl) {
                    className = readFile(td.decl);
                }
            }
        }
        
        // // B. Catch Method or Constructor declarations
        // case MethodDeclaration md: {
        //     // Check if the method's location fully contains the clone location
        //     if (isStrictlyContainedIn(cloneLoc, md.src)) {
        //         // Keep updating the methodName to the innermost one found so far
        //         if (md has decl) {
        //             methodName = md.decl;
        //         }
        //     }
        // }
        // case ConstructorDeclaration cd: {
        //     if (isStrictlyContainedIn(cloneLoc, cd.src)) {
        //         // Constructors use the class name
        //         if (cd has decl) {
        //             methodName = cd.decl;
        //         }
        //     }
        // }
    }

    return <className, methodName>;
}

/**
 * Helper to quickly find the AST for a specific file path.
 */
Declaration getFileAST(str filePath, list[Declaration] allASTs) {
    Declaration return_ast;
    for (Declaration ast <- allASTs) {
        if (ast has src && ast.src.path == filePath) {
            return ast;
        }
    }
    return return_ast;
}

// This is the record type for a single clone instance (member)
data CloneMember = cloneMember(
    int fileId, 
    int beginLine, 
    int endLine, 
    int beginCol, 
    int endCol
);

// This is the record type for a single clone class
data CloneClassJson = cloneClassJson(
    int id, 
    str \type, 
    list[CloneMember] members
);

/**
 * Maps a file path (from a loc) to a unique integer ID,
 * building up a map of all files and their IDs.
 */
tuple[map[str, int], list[tuple[int, str]]] collectFileInfos(set[set[loc]] cloneClasses) {
    map[str, int] pathToId = ();
    int nextId = 0;
    
    // Extract unique file paths from all clone classes
    set[str] uniquePaths = {l.file | set[loc] cc <- cloneClasses, loc l <- cc};
    
    list[tuple[int, str]] fileList = [];
    
    for (str path <- uniquePaths) {
        pathToId[path] = nextId;
        fileList += [<nextId, path>];
        nextId += 1;
    }
    
    return <pathToId, fileList>;
}

/**
 * Transforms a single loc into a CloneMember record, 
 * using the full ASTs to find context.
 */
CloneMember createCloneMember(loc cloneLoc, int fileId, list[Declaration] allASTs) { // <--- ADDED allASTs
    
    return cloneMember(
        fileId,
        cloneLoc.begin.line, 
        cloneLoc.end.line,
        cloneLoc.begin.column + 1,
        cloneLoc.end.column + 1
    );
}
/**
 * Generates the final JSON output structure.
 */
map[str, value] generateJsonOutput(
    str projectName, 
    int cloneType, // Use to set the type string
    set[set[loc]] cloneClasses,
    list[Declaration] allASTs
) {
    // 1. Collect file information
    tuple[map[str, int], list[tuple[int, str]]] fileData = collectFileInfos(cloneClasses);
    map[str, int] pathToId = fileData[0];
    list[tuple[int, str]] fileList = fileData[1];
    
    list[map[str, value]] jsonFiles = [];
    for (<id, path> <- fileList) {
        // Create the "files" array structure
        jsonFiles += ("id": id, "path": path);
    }
    
    // 2. Process clone classes
    list[map[str, value]] jsonCloneClasses = [];
    int classId = 1;
    
    str cloneTypeStr = "Type<cloneType>";
    
    for (cloneClass <- cloneClasses) {
        list[map[str, value]] membersJson = [];
        
        for (loc memberLoc <- cloneClass) {
            str filePath = memberLoc.file;
            int fileId = pathToId[filePath];
            
            CloneMember member = createCloneMember(memberLoc, fileId, allASTs);
            
            // Convert CloneMember record to JSON-compatible map
            membersJson += (
                "fileId": member.fileId,
                "beginLine": member.beginLine,
                "endLine": member.endLine,
                "beginCol": member.beginCol,
                "endCol": member.endCol
            );
        }
        
        // Convert CloneClassJson record to JSON-compatible map
        jsonCloneClasses += (
            "id": classId,
            "type": cloneTypeStr,
            "members": membersJson
        );
        
        classId += 1;
    }
    
    // 3. Assemble the final structure
    map[str, value] finalJsonStructure = (
        "project": projectName,
        "files": jsonFiles,
        "cloneClasses": jsonCloneClasses
    );
    
    return finalJsonStructure;
}