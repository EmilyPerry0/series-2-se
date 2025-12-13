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

import List;
import String;
import Node;
import Set;
import Relation;
import analysis::graphs::Graph;
import Location;
import IO;

import utils;

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

set[set[loc]] baxtersAlgo(list[Declaration] asts, int massThresh, real simThresh, int cloneType){
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
    list[ClonePair] allPairs = toList(allClonePairs);
    return removeSubsumedClones(generateCloneClasses(toSet(allPairs)));
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