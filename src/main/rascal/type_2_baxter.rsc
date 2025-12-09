module type_2_baxter

import lang::java::m3::Core;
import lang::java::m3::AST;
import lang::java::\syntax::Java18;

import IO;
import List;
import util::Maybe;
import String;

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
    int placeholderMassThreshVal = 10;
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
    map[int, list[tuple[loc, node]]] hash_buckets;
    int numThownOut = 0;
    int numIn = 0;
    for(ast <- asts){
        visit(ast){
            case node subtree : {
                if(calcMass(subtree) >= massThresh){
                //hash  i 
                // might need to switch to a worse hash function if we want to detect similar but not exactly the same clones
                // accoridng to the baxter paper, we might also want to make it so there are only size(asts) * 0.1 buckets
                str hashVal = md5Hash(subtree); // might need to strip things like the location so that doesn't affect hashing

                // add to bucket
                numIn += 1;

                }else{
                    numThownOut += 1;
                }
            }
        }
    }
    println(numThownOut);
    println(numIn);
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

    str sourceCode = readFile(sourceLoc);
    sourceCode = removeMultiLineComments(sourceCode);
    sourceCode = removeLineComments(sourceCode);
    return countLOC(sourceCode);
}