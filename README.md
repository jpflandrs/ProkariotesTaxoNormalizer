# ProkariotesTaxoNormalizer

## Aim of the program
The aim is to get a normalized presentation of the nomenclature hierarchy to document the taxonomic status of sequences in our (DNA/protein) banks ([riboDB](https://umr5558-proka.univ-lyon1.fr/riboDB/ribodb.cgi))

We collect:

                1 species tax_id          -- NCBI taxId
                2 genetic code            -- the species genetic code
                3 species                 -- name of a species (coincide with organism name for species-level nodes)
                4 genus                   -- genus name when available
                5 family                  -- family name when available
                6 order                   -- order name when available
                7 class                   -- class name when available
                8 phylum                  -- phylum name when available
                9 superkingdom            -- superkingdom (domain) name when available

This will be included in the "Fasta commentary" of a given sequence like here

```>Pantoea_phytobeneficialis|MSR2#R#T#S~GCF_009728735.1~NZ_CP024636.1~C[3875034..3875483]~2052056~11=Bacteria-Pseudomonadota-Gammaproteobacteria-Enterobacterales-Erwiniaceae-Pantoea-Pantoea_phytobeneficialis```

Note that we need also to include some relevant data concerning the organism (strain identification in a collection), its "quality" (Type strain), the technicial status of the genome (Reference, Representative, Complet etc. ), as well as technical data concernig the sequence (contig, position).

```>species|COLLECTION_ID#STRAIN_QUALITY~GENOME_ID~CONTIG~POSITION~species tax_id~genetic code=superkingdom-phylum-class-order-family-genus-species```

The "sub" levels and  the "kingdom" level are ommited. As it is this does not impairs too much the knowledge of the taxonomy level of a given Bacteria or Archaea. 

## Source of the data

The information is extracted from the European Nucleotide Archive (ENA) taxonomy XML file http://ftp.ebi.ac.uk/pub/databases/ena/taxonomy/taxonomy.xml.gz that is an xml image of the NCBI taxonomy tree.

## Outputs

The result is a compacted (serialized) dictionnary for the Julia language (taxonomy.gz.ser) and for Python (the pickle version taxonomy.gz.pkl). 
Basicallly the key of the dictionnary is the NCBI TaxId and the value is a vector of strings ```uniquedict[taxID]=[hierarchie,localdict["CODE"]]```
```2052056 => ["Bacteria-Pseudomonadota-Gammaproteobacteria-Enterobacterales-Erwiniaceae-Pantoea-Pantoea_phytobeneficialis","11"]```
```76629   => ["Bacteria-Mycoplasmatota-no_class-Mycoplasmoidales-Metamycoplasmataceae-Mycoplasmopsis-Mycoplasmopsis_gallopavonis","4"]```
This enable an easy construction of the Fasta commentary.

## Running

There is currently only one (mandatory) option "```-a```ction" with :

- "d" download from ENA
- "x" extract and construct
- "a" download extract and construct "a" for "all"
- "l" reading the dictionary (big output ! - only to test- )

And the target (usualy "taxonomy.gz")

```julia taxDBextract.jl -a a path_to_taxonomy.gz``` (action = all)

And in most of our programs taxDBextract.jl is called from Python as this was the main programming language before 2023.

## Usage

    taxodict=deserialize("path_to_taxonomydict")
    println("taxId: 2052056 is ",uniquedict["2052056"])

    taxId: 2052056 is ["Bacteria-Pseudomonadota-Gammaproteobacteria-Enterobacterales-Erwiniaceae-Pantoea-Pantoea_phytobeneficialis","11"]
    
## The program is not perfect :)

This is rather ugly program being the first attempt I made in Julia so do not be affraid.
Of course the commentaries in the program are mainly in french. 

## License 

Avalaible under the CECIL license terms.
