module type_2_baxter

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;


import IO;
import List;
import String;
import Node;
import Set;
import Relation;
import analysis::graphs::Graph;

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

    list[Declaration] asts = getASTs(benchmarkProject_loc); // step1: parse program and generate AST

    int massThreshVal = 15; // it's now 15, could go lower?
    real simThresh = 0.9;

    list[ClonePair] allPairs = toList(baxtersAlgo(asts, massThreshVal, simThresh, cloneType));
    set[set[loc]] cloneClasses = generateCloneClasses(toSet(allPairs));

    int clonedLOC = getTotalLOCFromAllClonePairs(allPairs);
    int totalLOC = getProjectLOCFromASTs(asts);
    real duplicatedPercent = 100.0 * clonedLOC / totalLOC;
    int biggestCloneSize = getBiggestCloneSize(allPairs);
    int biggestCloneClass = getBiggestCloneClass(cloneClasses);

    println("Summary Report:");
    println("Project: <projectName>");
    println("Clone Type <cloneType>");
    println("Duplicated Line %: <duplicatedPercent>%");
    println("Number of Clones: <size(allPairs)>");
    println("Biggest Clone: <biggestCloneSize> LOC");
    println("Biggest Clone Class: <biggestCloneClass> Members");
    println("Some Example Clones: ");
    for(i <- [0..1]){
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
    // for(pair <- allPairs){
    //     println("First: <pair.first_file>");
    //     println("Second: <pair.second_file>");
    // }
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
                    str hashVal = md5Hash(unsetRec(type2CloneASTFiltering(subtree), {"src", "decl", "typ"})); // not sure if stripping typ is necessary but it might be helpful
                    if(hashVal in hash_buckets){
                        hash_buckets = hash_buckets + (hashVal:hash_buckets[hashVal] + [<subtree.src, subtree>]);
                        // println("Bucket size: <size(hash_buckets[hashVal])>");
                    }else{
                        // hash_buckets = hash_buckets + (hashVal:hash_buckets[hashVal] + [<subtree.src, subtree>]);
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


    for(str hashVal <- sortedHashVals){
        currBucket = hash_buckets[hashVal];
        for(i <- currBucket){
            for(j <- currBucket){
    //             // disregard when talking about the exact same piece of code
    //             // check Similarity
                if(i[0] != j[0] && compareTree(i[1],j[1]) > simThresh){
                    allClonePairs = allClonePairs + {clonePair(i[0], j[0])};
                }
            }
        }
    }
                    //For each subtree s of i
    //                 println("loc: <i[0]>");
    //                 visit(i[1]){
    //                     case node subtree_i:{
    //                         //If IsMember(Clones,s)
                            
                            
    //                         switch (subtree_i){
    //                             case Declaration d:{
    //                                 println("subtree: <d.src>");
    //                             }
    //                         }
    //                         if(isMember(allClonePairs, subtree_i)){
    //                             allClonePairs = {n | ClonePair n <- allClonePairs, (n.first_file != subtree_i.src && n.second_file != subtree_i.src)};
    //                         }
    //                     } 
    //                 }
    //                 //For each subtree s of i
    //                 visit(j[1]){
    //                     case node subtree_j:{
    //                         //If IsMember(Clones,s)
    //                         if(isMember(allClonePairs, subtree_j)){
    //                             allClonePairs = {n | ClonePair n <- allClonePairs, (n.first_file != subtree_j.src && n.second_file != subtree_j.src)};
    //                         }
    //                     } 
    //                 }
    //             allClonePairs = allClonePairs + {clonePair(i[0], j[0])};
    //         }
    //     }
    //     }
    // }
    set[ClonePair] trimmed_clones = removeSubsumedClones(allClonePairs);
    return trimmed_clones;
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
    list[node] shared = nodes_i & nodes_j;  // intersection
    list[node] only_i = nodes_i - nodes_j;  // only in i
    list[node] only_j = nodes_j - nodes_i;  // only in j
    
    int S = size(shared);
    int L = size(only_i);
    int R = size(only_j);

    // println("<2.0 * S / (2.0 * S + L + R)>");
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
                        // println("<d.src>");
                        return true;
                    }
                }
            }
    }
    // println("not memeber");
    return false;
}

set[ClonePair] removeSubsumedClones(set[ClonePair] allClonePairs){
    // idea: loop through all of the clone pairs
    // if a clone pair's first file or second file is completely contained in another pair's first or second file, don't add it to the final set.
    set[ClonePair] cleanedClonePairs = {};
    bool shouldAdd = true;
    for(pair <- allClonePairs){
        shouldAdd = true;
        for(comparePair <- allClonePairs){
            if(pair == comparePair) continue;
            if(pair.first_file < comparePair.first_file && pair.second_file < comparePair.second_file || pair.second_file < comparePair.first_file && pair.first_file < comparePair.second_file){

            // }
            // if((pair.first_file < comparePair.first_file || pair.first_file < comparePair.second_file || pair.second_file < comparePair.first_file || pair.second_file < comparePair.second_file)){
                shouldAdd = false;
            }
        }
        if(shouldAdd){
            cleanedClonePairs = cleanedClonePairs + pair;
        }
    }
    return cleanedClonePairs;
}


/* steps (my idea):
1. take in all of the clone pairs
2. Create an empty list of clone classes
3. loop over all the clone pairs.
    3.5 in the loop, compare each pair to first of each clone class.
        if it has a Similarity above the threshold, it goes in the class. otherwise make a new class.
*/

/*
Second idea: workshopped with gemini: use graph theory and transitive closures to create the classes
    
*/

// might need to clean the pairs first
// set[set[loc]] generateCloneClasses(set[ClonePair] allPairs){
//     // list[list[loc]] cloneClasses;
//     rel[loc, loc] R = {<cp.first_file, cp.second_file> | ClonePair cp <- allPairs};
//     R = R + invert(R);
//     R = R + ident(domain(R) + range(R));
//     rel[loc, loc] R_closure = R+;

//     set[set[loc]] cloneClasses = {};
//     set[loc] remainingInstances = domain(R) + range(R);
//     while (!isEmpty(remainingInstances)) {
//         // Pick an arbitrary, un-processed instance
//         loc currentInstance = getOneFrom(remainingInstances);
        
//         // Find the set of all instances reachable from the current one
//         // This set is a maximal connected component (a Clone Class).
//         set[loc] newClass =  R_closure[currentInstance] + {currentInstance};
        
//         // Add the new class to the result set
//         cloneClasses += {newClass};
        
//         // Remove all instances in the new class from the list of remaining instances
//         remainingInstances = remainingInstances - newClass;
//     }
//     return cloneClasses;
// }

// set[set[loc]] generateCloneClasses(set[ClonePair] allPairs){
    
//     // 1. Collect all unique clone locations (nodes)
//     set[loc] nodes = {p.first_file | ClonePair p <- allPairs} 
//                    + {p.second_file | ClonePair p <- allPairs};
    
//     // 2. Convert the set of ClonePair data into a standard Rascal relation (set[tuple[loc, loc]])
//     // The Graph module uses set[tuple[N, N]] for edges.
//     rel[loc, loc] edges = {<p.first_file, p.second_file> | ClonePair p <- allPairs};
    
//     // 3. Create the graph
//     // Note: Since the relationship is symmetric, we treat this as an undirected graph, 
//     // or just rely on the connected component algorithm to handle it naturally.
//     Graph[loc] cloneGraph = Graph(nodes, edges);
    
//     // 4. Find the connected components (the clone classes)
//     // The components() function returns a set of sets of nodes (i.e., set[set[loc]]).
//     set[set[loc]] cloneClasses = connectedComponents(cloneGraph);
    
//     // An optional step: components() might return a set[set[loc]] where some singletons
//     // (a location with no partners) are also included if they were in the initial 'nodes' set.
//     // If you only want clone classes of size > 1 (a true clone *pair* or more), you can filter them.
//     // However, for completeness, we typically keep all components.
    
//     return cloneClasses;
// }

set[set[loc]] generateCloneClasses(set[ClonePair] allPairs){
    
    // 1. Collect all unique clone locations (nodes)
    // This isn't strictly needed for the connectedComponents function, 
    // but good practice if you wanted to include singletons.
    set[loc] nodes = {p.first_file | ClonePair p <- allPairs} 
                   + {p.second_file | ClonePair p <- allPairs};
    
    // 2. Convert ClonePair set into a standard Rascal relation (set[tuple[loc, loc]])
    rel[loc, loc] edges = {<p.first_file, p.second_file> | ClonePair p <- allPairs};
    
    // 3. Make the relation symmetric (undirected) since clone pairs are mutual
    rel[loc, loc] undirectedEdges = edges + invert(edges);
    
    // 4. Find the connected components (the clone classes)
    // The function expects a relation and is named connectedComponents
    // It infers the nodes from the relation's domain and range.
    set[set[loc]] cloneClasses = connectedComponents(undirectedEdges); 
    
    return cloneClasses;
}