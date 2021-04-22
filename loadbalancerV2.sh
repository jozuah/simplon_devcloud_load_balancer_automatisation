#!/bin/bash

#https://docs.microsoft.com/fr-fr/azure/virtual-machines/linux/tutorial-load-balancer

#transfert de clé de la VM2 de mon pc vers la VM1 dans le but d'établir une connection privée ssh entre la VM1 et la VM2 
#~scp -i keyVM1.pem /path/keyVM2.pem  VM1@IPVM1:/home/VM1/
#depuis la VM1 :
#~ssh -i keyVM2.pem VM2@IPVM2 

#Utilisation du script 
# ~ chmod +x script.sh  <=== donner les droit d'execution
# ~ ./script.sh  <==== run le script

#Définition du nom de ressource group par l'utilisateur

echo Entrer un nom de resource group :
read resourceGroup

echo Combien de VM voulez vous créer ?
read numberVM

az group create --name $resourceGroup --location eastus

az network public-ip create \
    --resource-group $resourceGroup \
    --name myPublicIP

az network lb create \
    --resource-group $resourceGroup \
    --name myLoadBalancer \
    --frontend-ip-name myFrontEndPool \
    --backend-pool-name myBackEndPool \
    --sku Standard
    --public-ip-address myPublicIP

az network lb probe create \
    --resource-group $resourceGroup \
    --lb-name myLoadBalancer \
    --name myHealthProbe \
    --protocol tcp \
    --port 80

az network lb rule create \
    --resource-group $resourceGroup \
    --lb-name myLoadBalancer \
    --name myLoadBalancerRule \
    --protocol tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name myFrontEndPool \
    --backend-pool-name myBackEndPool \
    --probe-name myHealthProbe

#Creation du virtual network et du subnetwork
az network vnet create \
    --resource-group $resourceGroup \
    --name myVnet \
    --subnet-name mySubnet

az network nsg create \
    --resource-group $resourceGroup \
    --name myNetworkSecurityGroup

az network nsg rule create \
    --resource-group $resourceGroup \
    --nsg-name myNetworkSecurityGroup \
    --name myNetworkSecurityGroupRule \
    --priority 1001 \
    --protocol tcp \
    --destination-port-range 80

for i in `seq 1 $numberVM`; do
    az network nic create \
        --resource-group $resourceGroup \
        --name myNic$i \
        --vnet-name myVnet \
        --subnet mySubnet \
        --network-security-group myNetworkSecurityGroup \
        --lb-name myLoadBalancer \
        --lb-address-pools myBackEndPool
done

az vm availability-set create \
    --resource-group $resourceGroup \
    --name myAvailabilitySet

#Set les VM Prix : 7,26€ option --no-wait pour ne pas attendre la creation des VMs
for i in `seq 1 $numberVM`; do
    az vm create \
        --resource-group $resourceGroup \
        --name myVM$i \
        --availability-set myAvailabilitySet \
        --nics myNic$i \
        --image UbuntuLTS \
        --size Standard_B1s \
        --admin-username azureuser \
        --generate-ssh-keys \
        --custom-data setVM.yml      
done

#On va montrer un tableau qui donne les adresses publiques de mes vm
az vm list-ip-addresses \
    --resource-group $resourceGroup \
    --output table

#creer une vm bastion qui va recuperer 
