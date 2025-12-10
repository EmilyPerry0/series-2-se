module type_2_baxter

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;

import IO;
import List;
import util::Maybe;
import String;
import Node;
import Set;

import utils;

/*
The algorithm consists of the following steps:
1. parse program and generate AST
2. serialize AST
3. apply suffix tree detection
4. decompose resulting type-1/type-2 token sequence into complete syntactic units
*/

int main(){
    loc smallsql_loc = |cwd:///smallsql0.21_src/|;
    loc hsql_loc = |cwd:///hsqldb-2.3.1/|;
    list[Declaration] asts = getASTs(smallsql_loc); // step1: parse program and generate AST
    int placeholderMassThreshVal = 20;
    real placeholderSimThresh = 0.9;
    baxtersAlgo(asts, placeholderMassThreshVal, placeholderSimThresh);
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

void baxtersAlgo(list[Declaration] asts, int massThresh, real simThresh){
    set[ClonePair] allClonePairs = {};
    
    map[str, list[tuple[loc, node]]] hash_buckets = ();
    list[str] allHashVals = [];
    int temp = 0;
    int non_hits = 0;
    int thrown_out = 0;
    for(ast <- asts){
        Declaration newAST = type2CloneASTFiltering(ast);
        visit(newAST){
            case node subtree : {
                if(calcMass(subtree) >= massThresh){
                    //hash  i 
                    // might need to switch to a worse hash function if we want to detect similar but not exactly the same clones
                    // accoridng to the baxter paper, we might also want to make it so there are only size(asts) * 0.1 buckets
                    str hashVal = md5Hash(unsetRec(subtree, {"src", "decl", "typ"})); // not sure if stripping typ is necessary but it might be helpful
                    if(hashVal in hash_buckets){
                        hash_buckets = hash_buckets + (hashVal:hash_buckets[hashVal] + [<subtree.src, subtree>]);
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


    for(str hashVal <- allHashVals){
        currBucket = hash_buckets[hashVal];
        for(i <- currBucket){
            for(j <- currBucket){
                // disregard when talking about the exact same piece of code
                // check Similarity
                if(i[0] != j[0] && compareTree(i[1],j[1]) > simThresh){
                    //For each subtree s of i
                    visit(i[1]){
                        case node subtree_i:{
                            //If IsMember(Clones,s)
                            if(isMember(allClonePairs, subtree_i)){
                                allClonePairs = {n | ClonePair n <- allClonePairs, n.first_file != subtree_i.src && n.second_file != subtree_i.src};
                            }
                        } 
                    }
                    //For each subtree s of i
                    visit(j[1]){
                        case node subtree_j:{
                            //If IsMember(Clones,s)
                            if(isMember(allClonePairs, subtree_j)){
                                allClonePairs = {n | ClonePair n <- allClonePairs, n.first_file != subtree_j.src && n.second_file != subtree_j.src};
                            }
                        } 
                    }
                    allClonePairs = allClonePairs + {clonePair(i[0], j[0])};
                }
            }
        }
    }
}

// a tiny bit slow but not horrible i guess (could change to not care about comments)
int calcMass(node astNode){
    // get string form version
    // take out all comments
    // then count loc
    loc sourceLoc = |http://www.example.org|;
    try 
        sourceLoc = astNode.src;
    catch:
        return -1;

    // str sourceCode = readFile(sourceLoc);
    // sourceCode = removeMultiLineComments(sourceCode);
    // sourceCode = removeLineComments(sourceCode);
    // return countLOC(sourceCode)
    return sourceLoc.length;
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
    set[node] nodes_i = collectNodes(stripped_i);
    set[node] nodes_j = collectNodes(stripped_j);
    
    // Calculate shared and different nodes
    set[node] shared = nodes_i & nodes_j;  // intersection
    set[node] only_i = nodes_i - nodes_j;  // only in i
    set[node] only_j = nodes_j - nodes_i;  // only in j
    
    int S = size(shared);
    int L = size(only_i);
    int R = size(only_j);

    return 2.0 * S / (2.0 * S + L + R);
}

set[node] collectNodes(node tree) {
    set[node] result = {tree};
    visit(tree) {
        case node n: result += {n};
    }
    return result;
}

bool isMember(set[ClonePair] allClonePairs, node s){
    for(clonePair <- allClonePairs){
        if(s.src == clonePair.first_file || s.src == clonePair.second_file){
            return true;
        }
    }
    return false;
}