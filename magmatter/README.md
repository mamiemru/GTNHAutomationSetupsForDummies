# LazyMagmatter
GTNH automation script for OC to deal with Magmatter Production in any case scenario


Program par claude code, il demande un subnet green (output des elements)
subnet blue (input des plasma), purple (storage des plasma)

dans le subnet vert placer une storage bus pour virer la magmatter ailleur (prio 1000), une stocking set en space et time pour re insertion.
les 3 subnets ont un adapteur connecté à une interface, le channel purple to blue a un transposer d'une interface vers un tank 
le tank est storage bus sur le blue, il y a un autre transposer depuis l'interface du sub green vers une trash à item.
mettre une database t3 dans un adapter.

Ce que j'ai remarqué des setup déjà présent sur d'autre tuto repo c'est qu'il ne prend pas comptes des lags serveur d'avoir un gros AE ou un serveur de merde.
Aussi que lorsqu'on craft un gros truc (genre la gate) on vide tout le storage qui sert à replanish le purple subnet donc la plus part des programmes crash car ils trouvent
pas les resources. Le miens il préfèrera attendre et toutes les 5 secondes re essayer ce qui est "interuption proof" et "mamie proof" (très important).

PS: Askip le adapter qui est entre OC et le subnet Blue ne sert à rien.


<img width="1257" height="1133" alt="image" src="https://github.com/user-attachments/assets/d89095a5-25f6-4971-ad4c-85a7785a4a35" />

<img width="670" height="944" alt="image" src="https://github.com/user-attachments/assets/96e823a1-e5f3-4dd6-a098-47ecfc870246" />


Le subnet Purple resemble à sa, son but est d'exposer que ce qui est utile, les drives sont des "default storages" car il faut vider l'interface après avoir transféré les fluids du purple vers blue subnet.
l'interface du haut est le mainnet de la base.

<img width="803" height="1179" alt="image" src="https://github.com/user-attachments/assets/509a992a-54c8-444b-8ead-405570609954" />
