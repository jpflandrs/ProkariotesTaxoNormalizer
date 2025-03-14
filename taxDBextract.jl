
try
    using Serialization
catch
    import Pkg
    Pkg.add("Serialization")     
    using Serialization
end
try
    using PyCall
catch
    import Pkg
    Pkg.add("PyCall")     
    using PyCall
end


@pyimport pickle

try
 import GZip
 catch
    import Pkg
    Pkg.add("GZip")     
    using GZip
end
try
    using ArgParse
catch
    import Pkg
    Pkg.add("ArgParse")     
    using ArgParse
end

try
    using FTPClient
catch
    import Pkg
    Pkg.add("FTPClient")     
    using FTPClient
end
    
"""
 taxDBextract.jl is a part of the riboDB engine
 
 Copyright or © or Copr. UCBL Lyon, France;  
 contributor : [Jean-Pierre Flandrois] ([2024/12/20])
 [JP.flandrois@univ-lyon1.fr]
 
 This software is a computer program whose purpose is to create the Web-Site PkXplore.
 
 This software is governed by the [CeCILL|CeCILL-B|CeCILL-C] license under French law and
 abiding by the rules of distribution of free software.  You can  use, 
 modify and/ or redistribute the software under the terms of the [CeCILL|CeCILL-B|CeCILL-C]
 license as circulated by CEA, CNRS and INRIA at the following URL
 "http://www.cecill.info". 
 
 As a counterpart to the access to the source code and  rights to copy,
 modify and redistribute granted by the license, users are provided only
 with a limited warranty  and the software's author,  the holder of the
 economic rights,  and the successive licensors  have only  limited
 liability. 
 
 In this respect, the user's attention is drawn to the risks associated
 with loading,  using,  modifying and/or developing or reproducing the
 software by the user in light of its specific status of free software,
 that may mean  that it is complicated to manipulate,  and  that  also
 therefore means  that it is reserved for developers  and  experienced
 professionals having in-depth computer knowledge. Users are therefore
 encouraged to load and test the software's suitability as regards their
 requirements in conditions enabling the security of their systems and/or 
 data to be ensured and,  more generally, to use and operate it in the 
 same conditions as regards security. 
 
 The fact that you are presently reading this means that you have had
 knowledge of the [CeCILL|CeCILL-B|CeCILL-C] license and that you accept its terms.
 
 """
 
function ArgParse.parse_item(::Type{Char}, x::AbstractString)
    return x[1]
end

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin

        "--action", "-a" #analyse
            help = "les actions sont t=téléchargement x=extraction a=analyse"
            arg_type = Char
            default = 'a'
            required = false

        "input"
            help = "nom du fichier ex:taxonomy.gz"
            required = true
    end
    
    return parse_args(s)
end

####

function verifMmm_sub_mmm(putatif::String) #sous espèce
    #println(putatif)
    if occursin("subsp.",putatif) || occursin(" pv. ",putatif) || occursin(" bv. ",putatif)
        #println(putatif)
        blocs=split(putatif,' ')
        
        l=length(blocs)
        #println(l)
        #Salmonella enterica subsp. arizonae serovar sort en erreur si on ne coupe pas
        if l==4 && ("A" <= SubString(putatif,1:1) <= "Z" ) &&   all(c->islowercase(c) | isspace(c), blocs[2]) && all(c->islowercase(c) | isspace(c), blocs[4]) 
            #println("SOUSESPECE")
            return true
        elseif l==4 && ("A" <= SubString(putatif,2:2) <= "Z" ) &&   all(c->islowercase(c) | isspace(c), blocs[2]) && all(c->islowercase(c) | isspace(c), blocs[4]) 
            #println("CANDIDATUS SOUSESPECE")
            return true
        else 
            return false
        end
    else
        return false
    end
end

function verifMmm_mmm(putatif::String) #espèce
    #println("verifMmm_mmm  ",putatif)
    blocs=split(putatif,' ')
    l=length(blocs)
    putatif=replace(putatif,'.' =>"")
    #println(SubString(putatif,2))
    #println(replace(SubString(putatif,2), " " => ""))
    if l == 2 && ("A" <= SubString(blocs[1],1:1) <= "Z" ) &&  all(c->islowercase(c) | isspace(c), replace(SubString(putatif,2), " " => "")) #on colle nom genre  et espece => Genreespece et on teste [G]enreespece
        #println("ESPECE")
        return true
    elseif l == 2 && ("A" <= SubString(blocs[1],2:2) <= "Z" ) &&  all(c->islowercase(c) | isspace(c), replace(SubString(putatif,3), " " => "")) #Candidatus 
        #println("CANDIDATUS")
        return true
    else 
        return false
    end
end

function verifMmm(putatif::String) #genre
    #println("verifMmm ",putatif)
    putatif=replace(putatif,'.' =>"", '/' => '+')
    #println(putatif)
    blocs=split(putatif,' ')
    l=length(blocs)
    #println(l," " ,SubString(putatif,1:1))
    #println("# ",SubString(putatif,1:1))
   
    if l == 1 && ("A" <= SubString(putatif,1:1) <= "Z" ) &&  all(c->islowercase(c) | isspace(c), SubString(putatif,2)) #SubString(sp[1], 2)
        #println("GENRE OU AUTRE")
        return true
    elseif l == 1 && ("A" <= SubString(putatif,2:2) <= "Z" ) &&  all(c->islowercase(c) | isspace(c), SubString(putatif,3)) #SubString(sp[1], 2)
        #println("CANDIDATUS  ",putatif)
        return true
    
    else
        return false
    end
end

function recupValeur(phrase::String,itemAvant::String,itemApres::String,volubile::Bool)
    if occursin(itemAvant,phrase) && occursin(itemApres,phrase)
        lignepropreMaitre=replace(phrase, itemAvant => '$')
        lignepropreMaitre=replace(lignepropreMaitre, itemApres => '@')
        retour=split(split(lignepropreMaitre,'$')[2],'@')[1]
        return(strip(String(retour)))
    else 
        if volubile ==1
            println(stderr, "recup impossible revoir les bornes ")
            println(stderr, "abortion de recup dans [ ",phrase," ]  devant [ ",itemAvant," ] derrière [ ",itemApres," ]")
        end
        return("absent")  
    end
end
        
function casParticuliers(putatifRang::String,putatifNom::String)
    if occursin("endosymbionts",putatifNom)
        putatifNom="no_"*putatifRang 
    elseif occursin("subdivision",putatifNom)
        putatifNom="no_"*putatifRang 
    elseif occursin("\''",putatifNom)
        putatifNom="no_"*putatifRang 
    end
    
    if occursin("candidate division",putatifNom) || occursin("candidate phylum",putatifNom) #on rend automatique MAIS NB si on trouve un vrai après celui-ci est non pris en compte
        putatifRang="phylum"
        putatifNom=strip(replace(putatifNom,"unclassified" => "")) #les candidate sont parfois unclassified
        putatifNom=strip(replace(putatifNom,"Incertae Sedis" => "")) #les candidate sont parfois Incertae Sedis
        putatifNom=replace(putatifNom,"candidate division" => "cPhylum@","candidate phylum" => "cPhylume@")
        PS=split(putatifNom,"@")
        putatifNom=replace(strip(String(PS[1]))*"_"*strip(String(PS[2])),'-'=>'_','.'=>"")
        #println("candidate      ",putatifNom)
    elseif occursin(" Family ",putatifNom)  #on rend automatique MAIS NB si on trouve un vrai après celui-ci est non pris en compte
        putatifRang="family"
        putatifNom=strip(replace(putatifNom,"unclassified" => "")) #les candidate sont parfois unclassified
        putatifNom=strip(replace(putatifNom,"Incertae Sedis" => "")) #les candidate sont parfois Incertae Sedis
        putatifNom=replace(putatifNom,"Family" => "@")
        PS=split(putatifNom,"@")
        putatifNom="cFamily_"*replace(strip(String(PS[1]))*"_"*strip(String(PS[2])),' '=>'_','.'=>"")
        #println("cFamily      ",putatifNom)
    elseif occursin(" Order ",putatifNom)  #on rend automatique MAIS NB si on trouve un vrai après celui-ci est non pris en compte
        putatifRang="order"
        putatifNom=strip(replace(putatifNom,"unclassified" => "")) #les candidate sont parfois unclassified
        putatifNom=strip(replace(putatifNom,"Incertae Sedis" => "")) #les candidate sont parfois Incertae Sedis
        putatifNom=replace(putatifNom,"Order" => "@")
        PS=split(putatifNom,"@")
        putatifNom="cOrder_"*replace(strip(String(PS[1]))*"_"*strip(String(PS[2])),' '=>'_','.'=>"")
        #println("cOrder      ",putatifNom)
    
    end
    return putatifRang,putatifNom        
end


"""
    xtracProTax(fichiertaxo::String)

le fichier XML est lu ligne à ligne zt on sélectionne PRO
les lignes de type Majeur DEBUT enclanchent la booleenne continu true et est interprétée c'est le niveau théorique espèce
les lignes INTERMEDIAIRE sont lues tant que continu et contiennent la hiérarchie 
les lignes de type LA FIN terminent les lectures et continu devient à nouveau false 

"""
function xtracProTax(fichiertaxo::String)  
    #globales pour la fonction
    continu::Bool=false
    compteur::Int64=0
    uniquedict=Dict{}()
    localdict=Dict{}()
    # on va donner une valeur aux limites permettant de récupérer les lignes
    #comme ça en cas de changement de format (il y en a eu induits par le décompressage par ex) on gère facilement 
    #en donnant l'exemple et ceci pourrait être externalisé dans un fichier de contrôle
    limites0=findfirst("<taxon","<taxon scientificName") #l'exemple'
    limites1=findfirst("<taxon","    <taxon scientificName") #l'exemple'
    limites2=findfirst("</lineage>","  </lineage>") #l'exemple'
    println(stderr, "En route pour le premier quadrille " * fichiertaxo * " hop")
    
    taxoExpanded = GZip.open(fichiertaxo) 
    print("  lu    \n")
    #init des variables réuntilisées
    taxID::String=""
    rangNiveau0::String=""
    Niveau0Nom::String=""
    putatifRang::String=""
    putatifNom::String=""
    for line in eachline(taxoExpanded)
        
        # LA SELECTION DES LIGNES PERTINENTES #cas <taxon scientificName="environmental samples" ???
        #####################################
        if (findfirst("<taxon",line) == limites0 ) && (occursin("""taxonomicDivision="PRO""",line) || occursin("""taxonomicDivision="ENV""",line)) && (occursin("""rank="species""",line) || occursin("""rank="subspecies""",line)|| occursin("""rank="biotype""",line) || occursin("""scientificName="environmental samples""",line))  #type Majeur DEBUT
            ##println(line)
            #soucis
            #<taxon scientificName="Mycobacterium tuberculosis variant bovis" taxId="1765" parentTaxId="1773" rank="biotype" hidden="true" taxonomicDivision="PRO" geneticCode="11">
            #  taxId   1765        local=>  Dict("PHYLUM" => "Actinomycetota", "domain" => "Bacteria", "CODE" => "11", "RANG" => "no_rank", "ORDER" => "Mycobacteriales", "TAG" => "drama", "SUBSPECIES" => "no_subspecies", "GENUS" => "Mycobacterium", "FAMILY" => "Mycobacteriaceae", "CLASS" => "Actinomycetes", "SPECIES" => "Mycobacterium tuberculosis", "rank0" => "SUBSPECIES", "nomSp0" => "Mycobacterium tuberculosis.bovis")   uniq=> Bacteria-Actinomycetota-Actinomycetes-Mycobacteriales-Mycobacteriaceae-Mycobacterium-Mycobacterium_unclassified
            #    <taxon scientificName="Acetobacter subgen. Acetobacter" taxId="151157" rank="subgenus" hidden="false"/>
            #<taxon scientificName="Haemophilus influenzae biotype aegyptius" taxId="725" parentTaxId="727" rank="biotype" hidden="true" taxonomicDivision="PRO" geneticCode="11">
            # Initialisations 
            localdict=Dict("TAG"=>"faux", "rank0"=>"unknown","nomSp0" => "unknown", "RANG"=>"no_rank", "SPECIES" =>"no_species", "SUBSPECIES" =>"no_subspecies","GENUS"=>"no_genus","FAMILY"=>"no_family","ORDER"=>"no_order","CLASS"=>"no_class","PHYLUM"=>"no_phylum","DOMAIN"=>"no_domain","CODE"=>"unknown")
            compteur=0
            #lectures de cette premiere ligne du bloc
            taxID=recupValeur(line,"taxId=\"","\" ",true) #STRIP FAIT
            rangNiveau0=replace(recupValeur(line,"rank=\"","\" ",false))
            Niveau0Nom=replace(recupValeur(line,"scientificName=\"","\" ",false)," variant " => " bv. " ," biotype " => " bv. ") #correction des sousgenres on colle par un "."

            #le niveau nom ne peut pas dépasser 4 mots après correction Candidatus
            #Niveau0Nom=replace(Niveau0Nom,"Candidatus " => 'c') 
            #Niveau0NomListe=split(putatifNom," ")
            #if length(Niveau0NomListe) > 4:
                #Niveau0Nom=Niveau0NomListe[1]+' '+Niveau0NomListe[2]+' '+Niveau0NomListe[3]+' '+Niveau0NomListe[4]
            #end
            #remplissage dictionnaire
            localdict["rank0"] = uppercase(rangNiveau0)
            localdict["nomSp0"] = Niveau0Nom
            #problème des faux codes !
            # geneticCode="11"> <-correct
            # geneticCode="11" plastIdGeneticCode="11" 
            tmpcod::String=recupValeur(line," geneticCode=\"","\"",false)
            #println(tmpcod)
            #occursin("GeneticCode",recupValeur(line," geneticCode=\"","\">",false)) ? tmpcod=recupValeur(line," geneticCode=\"","\" ",false) : tmpcod=recupValeur(line," geneticCode=\"","\">",false)
            localdict["CODE"] = tmpcod #STRIP FAIT #### bug à cause de plastIdGeneticCode dans 3 cas sur 180000 génomes
            # geneticCode="11" plastIdGeneticCode="11" (taxId="2768739")
            continu=true
            
        # LA LIGNE DE TETE 0
        #####################################
        elseif findfirst("<taxon",line) ==limites1 && continu && occursin("cellular organisms",line)==0 && occursin("root",line)==0     #on ne lit pas les hierarchies commones à tous # cas "Candidatus Nostocoida limicola I"
            ##println(line)
            compteur=compteur+1
            putatifRang=replace(recupValeur(line,"rank=\"","\" ",false),"subgenus" => "genus" )#STRIP FAIT
            putatifNom=replace(recupValeur(line,"scientificName=\"","\" ",false)," subgen. "=> "." ) #STRIP FAIT #  CAS COUAX  <taxon scientificName="Citrobacter freundii complex" taxId="1344959" rank="species group" hidden="false"/>
            Niveau0NomListe=split(putatifNom," ")
            
            
            if occursin("Candidatus ",putatifNom) ||  occursin("""'""",putatifNom)  || occursin("(",putatifNom) || occursin("INCERTAE SEDIS",uppercase(putatifNom)) # ajout de IS
                putatifNom=replace(putatifNom,"Candidatus " => 'c') 
                putatifNom=strip(replace(putatifNom,"""' """ => "(","""'""" => "")) #cas des simple quotes (1/500000) """' """ => "(")
                putatifNom=replace(putatifNom, " incertae sedis" => "_incertae sedis",  " Incertae Sedis" => "_incertae sedis") #Actinomycetes incertae sedis
                #putatifNom=replace(putatifNom,"\''" => "")
                putatifNom=strip(String(split(putatifNom,"(")[1])) #STRIP FAIT  : introduisait une espace
            end
            #<taxon scientificName="Mycobacterium tuberculosis variant bovis" taxId="1765" parentTaxId="1773" rank="biotype" hidden="true" taxonomicDivision="PRO" geneticCode="11">
            truc=strip(String(split(putatifNom,' ')[1]))
            truc=String(truc)
            #on vérifie les cas très particuliers
            putatifRang,putatifNom=casParticuliers(String(putatifRang),String(putatifNom)) #STRIP FAIT #STRIP FAIT
            ##println(putatifRang,"  ",putatifNom)
            # LA PREMIERE LIGNE DU BLOC A LIRE
            #####################################
            if compteur == 1
                #println(compteur)
                #putatifRang=="species group") 
                #|    <taxon scientificName="Acetobacter subgen. Acetobacter" taxId="151157" rank="subgenus" hidden="false"/>|
                if (putatifRang=="genus" || putatifRang=="species group" || putatifRang=="biotype"|| putatifRang=="subgenus" || putatifRang=="species subgroup") && verifMmm_mmm(localdict["nomSp0"]) && localdict["rank0"]=="SPECIES" #le nom est à 100% correct
                    ##println("cas 1")
                    localdict["TAG"]="vrai"
                    #println("cas 1.1")
                    localdict[uppercase(putatifRang)]=putatifNom
                    localdict["SPECIES"]=localdict["nomSp0"]
                    ##println("cas 1.2")
                    
                elseif putatifRang =="species" && verifMmm_sub_mmm(localdict["nomSp0"]) && (localdict["rank0"]=="SUBSPECIES" || localdict["rank0"]=="BIOTYPE") #rank="subspecies" en 0 et species en 1 c'est bon'
                    ##println("cas 2a SSP ",line)
                    
                    localdict["SUBSPECIES"]=localdict["nomSp0"]
                    localdict["SPECIES"]=recupValeur("D_"*localdict["nomSp0"],"D_"," subsp",false) #nom espèce
                    localdict["TAG"]="vrai"
                    
                elseif putatifRang =="subspecies" && verifMmm_sub_mmm(localdict["nomSp0"]) #une subspecies non déclarée en 0 et déclarée en 1 qui devient canonique subsp.
                    ##println("cas 2b SSP ",line)
                    localdict["SUBSPECIES"]=putatifNom
                    localdict["SPECIES"]=recupValeur("D_"*localdict["nomSp0"],"D_"," subsp",false) #nom espèce
                    localdict["TAG"]="vrai"
                
                elseif localdict["rank0"]=="SPECIES" && occursin("unclassified ",putatifNom) && putatifRang == "species"  && putatifRang == "subspecies" # le premier terme devrait être un genre|| occursin("INCERTAE SEDIS",uppercase(putatifNom)   #"ORDER" =>"unclassified Bacteroidetes Order II."-> "*Bacteroidetes Order II._unclassified"
                    ##println("cas 3 Xxx ",line)
                    #putatifNom=String(split(putatifNom,"(")[1])
                    #putatifNom=replace(putatifNom,"Candidatus " => 'c')
                    putatifNom=replace(putatifNom, "unclassified " => "") # : introduisait une espace potentiellement
                    #truc=String(split(putatifNom,' ')[1]) # a voir
                    #println("*",truc,typeof(truc))
                    if verifMmm(truc)
                        #println("226")
                        
                        putatifNom=strip(truc)*"_unclassified" #STRIP FAIT : introduisait une espace
                        putatifNom="*"* putatifNom
                        localdict["TAG"]="unclassified"
                    else
                        #println("231")
                        localdict["TAG"]="drama"
                    end
                    #println("234")
                    localdict[uppercase(putatifRang)]=putatifNom #ancien strip inutile à voir 
                elseif localdict["rank0"]=="SPECIES" && occursin("incertae sedis",putatifNom) 
                    ##println("cas 3 Yyy ")
                    #putatifNom=split(putatifNom,"(")[1]
                    #putatifNom=replace(putatifNom,"Candidatus " => 'c')
                    #truc=split(String(split(putatifNom,' ')[1]))
                    #println("*",truc,typeof(truc))
                    if verifMmm(truc)
                        ## antérieur !!! putatifNom=replace(putatifNom, " incertae sedis" => "_incertae sedis",  " Incertae Sedis" => "_incertae sedis") #Actinomycetes incertae sedis
                        putatifNom=titlecase(putatifNom)
                        putatifNom=replace(putatifNom,' ' => "")
                        putatifNom="*"* putatifNom #*Actinomycetes_IncertaeSedis
                        #println("putatifNom  incertae  ",putatifNom)
                        localdict["TAG"]="incertae"
                    else
                        localdict["TAG"]="drama"
                    end
                else 
                    # if putatifRang in ["genus","family","order","class","phylum","domain"]
                    #     println(stderr,"drama ",uppercase(putatifRang),"   ",putatifNom)
                    # end
                    localdict["TAG"]="drama"
                    localdict[uppercase(putatifRang)]=putatifNom
                end
                
            #### maintenant les autres lignes avec les niveaux ####
            elseif putatifRang in ["genus","family","order","class","phylum","domain"]  #"'Thalassorhabdus' Choi et al. 2018
                #println(" 236 ok ")
                # VERIFIER !!! le traiement des unclassified et uncertae et potentiel / dans nom

                putatifRang=uppercase(putatifRang)
                localdict[uppercase(putatifRang)]=putatifNom
            else
                
                #println("MErDE     ",uppercase(putatifRang),"  ",line)
            end
                
        elseif findfirst("</lineage>",line) ==limites2  && continu #type LA FIN
            #println("IIeme")
            try
                #println(line)
                #println(taxID)
                hierarchie=localdict["DOMAIN"]*"-"*localdict["PHYLUM"]*"-"*localdict["CLASS"]*"-"*localdict["ORDER"]*"-"*localdict["FAMILY"]*"-"*localdict["GENUS"]
                #print("1 localdict ",localdict,"\n")
                #uniquedict[taxID]
                if localdict["TAG"] == "vrai"
                    if localdict["SUBSPECIES"] != "no_subspecies"
                        hierarchie=hierarchie*"-"*replace(localdict["SUBSPECIES"],' ' =>'_')
                    elseif  localdict["SPECIES"] != "no_species"
                        hierarchie=hierarchie*"-"*replace(localdict["SPECIES"],' ' =>'_')
                    end
                elseif localdict["TAG"] == "unclassified"  #["GENUS","FAMILY","ORDER","CLASS","PHYLUM","DOMAIN"]
                    hierarchie=hierarchie*"-"*localdict["ABSENT"]
                elseif localdict["TAG"] == "drama" || localdict["TAG"] == "incertae"
                    
                    if localdict["GENUS"] != "no_genus"  #"'Thalassorhabdus' Choi et al. 2018
                        #if occursin("\'",localdict["GENUS"])
                            #nomfinal=recupValeur(nomfinal,"\'","\'",false)
                        #end                                                        #RELIQUE VERIFIER !!!
                        nomfinal=localdict["GENUS"]*"_"*"unclassified"
                    elseif localdict["FAMILY"] != "no_family"
#                        if occursin("\'",localdict["FAMILY"])
#                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
                        #end                                                        #RELIQUE VERIFIER !!!
                        nomfinal=localdict["FAMILY"]*"_"*"unclassified"
                    elseif localdict["ORDER"] != "no_order"
#                        if occursin("\'",localdict["ORDER"])
#                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
                        #end                                                        #RELIQUE VERIFIER !!!
                        nomfinal=localdict["ORDER"]*"_"*"unclassified"
                    elseif localdict["CLASS"] != "no_class"
#                        if occursin("\'",localdict["CLASS"])
#                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
                        #end                                                        #RELIQUE VERIFIER !!!
                        nomfinal=localdict["CLASS"]*"_"*"unclassified"
                    elseif localdict["PHYLUM"] != "no_phylum"
#                        if occursin("\'",localdict["PHYLUM"])
#                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
#                        end
                        nomfinal=localdict["PHYLUM"]*"_"*"unclassified"
                    else
                        nomfinal=localdict["DOMAIN"]*"_"*"unclassified"
                    end
#                elseif localdict["TAG"] == "incertae"
                    
#                    if localdict["GENUS"] != "no_genus"  #"'Thalassorhabdus' Choi et al. 2018
#                        #if occursin("\'",localdict["GENUS"])
#                            #nomfinal=recupValeur(nomfinal,"\'","\'",false)
#                        #end                                                        #RELIQUE
#                        nomfinal=localdict["GENUS"]*"_"*"unclassified"
#                    elseif localdict["FAMILY"] != "no_family"
##                        if occursin("\'",localdict["FAMILY"])
##                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
#                        #end                                                        #RELIQUE VERIFIER !!!
#                        nomfinal=localdict["FAMILY"]*"_"*"unclassified"
#                    elseif localdict["ORDER"] != "no_order"
##                        if occursin("\'",localdict["ORDER"])
##                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
#                        #end                                                        #RELIQUE VERIFIER !!!
#                        nomfinal=localdict["ORDER"]*"_"*"unclassified"
#                    elseif localdict["CLASS"] != "no_class"
##                        if occursin("\'",localdict["CLASS"])
##                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
#                        #end                                                        #RELIQUE VERIFIER !!!
#                        nomfinal=localdict["CLASS"]*"_"*"unclassified"
#                    elseif localdict["PHYLUM"] != "no_phylum"
##                        if occursin("\'",localdict["PHYLUM"])
##                            nomfinal=recupValeur(nomfinal,"\'","\'",false)
#                        #end                                                        #RELIQUE VERIFIER !!!
#                        nomfinal=localdict["PHYLUM"]*"_"*"unclassified"
#                    else
#                        nomfinal=localdict["domain"]*"_"*"unclassified"
#                    end
                hierarchie=hierarchie*"-"*nomfinal
            end
                uniquedict[taxID]=[hierarchie,localdict["CODE"]]
                # println("###  ",taxID,"  @ ",uniquedict[taxID][1])
                #println("  taxId   ",taxID,"        local=>  ",localdict,"   uniq=> ",uniquedict[taxID][1])
                
                continu=false
                
                empty!(localdict)
                
            catch
                println(stderr,taxID," ERREUR  -> ",localdict)
                try
                    println(stderr,taxID,"  ",uniquedict[taxID])
                catch
                    println(stderr,"???")
                end
            end
        end
    end
    println("SERIALISE")
    serialize(replace(fichiertaxo,".gz" => ".ser"), uniquedict)
    out = open(replace(fichiertaxo,".gz" => "~.pkl"),"w")
    pickle.dump(uniquedict, out)
    close(out)
    println("serialisation faite")
    
end
"""
Récupère à l'EBI le XML de la taxonomie
"""
function telechargetaxo(inputfile)
    println(stderr, "ftp telechargement " * inputfile * "...")
    #try
        print("demande ftp")
        ftp = FTP(hostname="ftp.ebi.ac.uk", username="", password="")
        print("ftp: $ftp")
        cd(ftp, "pub/databases/ena/taxonomy")
        print("\n----- je charge...-----$ftp")
        download(ftp, "taxonomy.xml.gz",inputfile)
        print("\n----- chargement fait -----\n")
        close(ftp)
    #catch
        #println(stderr, "Erreur pendant le process ftp \n",logftp, "\n", logdownload, "\n")
    #end
end

#gardé pour des tests
function analyse(inputfile)
    println("analyse")
    uniquedict=Dict{}()
    uniquedict=deserialize(inputfile)
    println(length(uniquedict))
    # reduitDict=Dict{}()
    println("taxId: 1852021 est ",uniquedict["1852021"])
    println("145391 est ",uniquedict["145391"])
    for i in keys(uniquedict)
        println(i,"  ",uniquedict[i])
    end
    # pickle.dump(uniquedict,open(replace(inputfile,".ser" => "~.pkl"), "w"))
end








####


#MAIN EST INACTIF DU FAIT DE L'APPEL VIA PyCall

 function main()
    args = parse_commandline()
    println(stderr,args)
    
    jobin=args["input"]
    

    println(stderr,jobin)
 #    if isnothing(args["parameter"]) == false
 #        global R = eval(Meta.parse(read(open(args["parameter"], "r"), String)))
 #    end
 #    if args["list"] == false
 #        correction_multi(args, open(args["input"], "r"), stdout)
 #    else
        
 #    temp = split(read(open(args["input"], "r"), String), "\n")
 #    temp = temp[length.(temp) .> 0]
 #    for i = 2:2:length(temp)
     #try
        if args["action"] == 'd' 
            println(stderr, "Processing " * jobin * "...  ",args["action"])
            println("copie sur web")
            telechargetaxo(jobin)
        elseif args["action"] == 'x' #extract
            println(stderr, "Processing " * jobin * "...  ",args["action"])
            xtracProTax(jobin)
        elseif args["action"] == 'a' #whole process
            println(stderr, "Processing " * jobin * "...  ",args["action"])
            println("copie sur web")
            telechargetaxo(jobin)
            xtracProTax(jobin)
        elseif args["action"] == 'l' # lecture - reading
            println(stderr, "Processing " * jobin * "...  ",args["action"])
            analyse(jobin*(".ser"))
        end
        println(stderr, "tout va bien " * jobin * ".")
     #catch
        #println(stderr, "Erreur pendant le process " * jobin * ".")
        #println(stderr)
     #end
 #     time julia taxDBextract.jl -a a Position_taxonomy.gz 

 end

 main()

