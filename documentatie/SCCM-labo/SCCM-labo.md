# Projecten 3: SCCM labo
<br>

# Inoud:

- Inleiding: algemene uitleg bij de opstelling
- Uitleg bij opstelling:
    * Software overzicht: oa gebruikte base boxes, Windows tools en te deployen software.
    * Active Directory Server
    * Deployment Server
    * Windows 10 Client
- Reproductie instructies
- Bronnen
- Problemen en oplossingen

# Inleiding:

De bedoeling van dit labo is het geautomatiseerd opzetten van een AD en Deployment Server die op hun beurt een Windows 10 client zullen kunnen deployen met minimale manuele interventie. Om deze hoge graad van automatisatie te verwezelijken werd voor Vagrant gekozen. Tijdens provisioning zullen Powershell scripts opgeroepen worden die instaan voor de volledige configuratie van de servers. Deze scripts bestaan voornamelijk uit AD en SCCM commandlets gegroepeerd in methoden. Eens de AD en Deployment server geconfigureerd zijn kunnen we een lege Virtualbox VM aanmaken en starten. Windows 10 zal dan automatisch gedeployed worden met een select aantal applicaties.


# Uitleg bij opstelling:

### Software overzicht:

- Vagrant:
    * base box: gusztavvargadr/sql-server
    * base box: gusztavvargadr/windows-server
- Virtualbox
- Windows Server 2019
- SQL Server 2017
- Microsoft Assessment and Deployment Kit (ADK)
- Microsoft ADK Preinstallation Environment (PE) add-on
- Microsoft IIS
- Windows Server Update Services (WSUS)
- System Center Configuration Manager (SCCM)
- Te deployen applicaties:
    * Adobe Reader DC
    * 7-Zip
    * Notepad++

### Relevante configuratie bestanden:

- [Vagrantfile](../../Vagrantfile)
- [Vagrant-hosts.yml](../../vagrant-hosts.yml)
- [srv-AD_part1.ps1](../../provisioning/srv-AD_part1.ps1) / [srv-AD_part2.ps1](../../provisioning/srv-AD_part2.ps1)
- [srv-SCCM_part1.ps1](../../provisioning/srv-SCCM_part1.ps1) / [srv-SCCM_part2.ps1](../../provisioning/srv-SCCM_part2.ps1)
- [srv-SCCM_config.ps1](../../provisioning/srv-SCCM_config.ps1)

**Opmerking**: De powershell scripts met bv '-step1' toegevoegd in de naam zijn opgesplitste versies van de originele scripts. Dit om uit te kunnen voeren tussen de nodige reboots van de servers tijdens provisioning.


# AD Server (srv-AD):

* [srv-AD_part1.ps1](../../provisioning/srv-AD_part1.ps1)

### 1. config_basics  
basis configuratie uitvoeren op de netwerk interfaces.  
ipv6 uitschakelen en duidelijke namen toewijzen aan de nat en hostonly interface.

### 2. config_adds  
We installeren de domain services en configureren een forest. De gekozen domeinnaam is 'thovan.gent'. Het wachtwoord kan enkel als Secure String meegegeven worden. Elders in de opstelling moet dit ook via deze manier gebeuren.  

  **REBOOT**

* [srv-AD_part2.ps1](../../provisioning/srv-AD_part2.ps1)

### 3. dns_put_ip  
Op de hostonly interface passen we het DNS adres aan van 127.0.0.1 naar 192.168.56.31. Het blijven gebruiken van het loopback adres heeft in het verleden al voor problemen gezorgd bij replicatie wanneer er twee domein controllers bestaan. Dat is hier niet het geval. Toch pas ik het aan om zeker te zijn.

### 4. dns_extra_zones  
We maken een reverse dns zone aan voor ons gebruikte subnet. Dit gebeurt niet direct automatisch heb ik gevonden. Een optionele stap.

### 5. config_nat  
We stellen srv-AD als NAT-toegangsrouter. Dit was niet verplicht maar werd altijd gedaan in vorige labo's en ik vond dat het in dit scenario ook paste. Het gebruikte commando om NAT te configureren na role based installatie, 'netsh', is in mijn ervaring niet meer 100% compatibel op Windows Server 2019. Het is tegenwoordig nog mogelijk om bijvoorbeeld internettoegang te verschaffen voor een client maar na herstart van srv-AD werkt dit niet meer.  
Wat wel mogelijk zou kunnen werken is het deployen van een NAT virtuele switch zoals [hier](https://www.petri.com/using-nat-virtual-switch-hyper-v) uitgelegd. We moeten dan wel eerst de 'hyper-v' rol installeren. Hier was ik geen voorstander van omdat we dan virtualisatie binnen virtualisatie hadden gebruikt.

### 6. config_dhcp  
We installeren de DHCP rol en stellen srv-AD in als DHCP server. De gebruikte range is van 192.168.56.12 naar 192.168.56.254. We vergeten ook niet enkele belangrijke opties in te stellen zoals het ip voor de DNS server en default gateway. Zonder dit zou pxe boot falen.  
Er werd ook een workaround gebruikt om deze instelling te kunnen maken. De standaard gebruikte account op deze base box is "Vagrant". Deze account heeft echter niet de juiste credentials om DHCP instellingen te maken. Dus werd er CimSession gemaakt met de credentials van "Administrator".

### 7. create_config_container  
We maken de System Management Container aan. Deze container zal gebruikt worden om data te kunnen publiceren naar de Active Directory. Het is één van de prerequisites voor SCCM.  
Controle delegeren naar srv-SCCM zullen we later moeten doen omdat deze machine op dit moment nog niet bestaat.  
Voor duidelijkheid, de uitvoeringsvolgorde van provisioning scripts is:  
`srv-AD_step1.ps1 > srv-AD_step2.ps1 > srv-SCCM_step1.ps1 > srv-SCCM_step2.ps1 > srv-SCCM_config.ps1`

### 8. extend_ad_schema  
Een andere SCCM preresuisite: het active directory schema uitbreiden. Dit kan gedaan worden via een exe die hier speciaal voor dient in de installatiemedia van SCCM. Om deze exe juist te kunnen laten uitvoeren moeten we weer hogere provileges hebben dan wat de standaard "Vagrant" account heeft. Deze keer gebruiken we een credential object met de rechten van de "Administrator" account. Het resultaat van de uitvoering is terug te vinden in `C:\ExtADSch.txt`

### 9. config_firewall  
Om srv-AD en srv-SCCM correct met elkaar te kunnen laten communiceren gaan we group policies geruiken die de gewenste firewall instellingen zullen maken. Deze group policies werden eerst manueel aangemaakt en dan geexporteerd. In deze functie worden ze terug geimporteerd.  
Specifiek gaan we regels maken voor:
  * File en Printer sharing (*voorgedefinieerd*) 
  * Windows Management Instrumentation (*voorgedefinieerd*)
  * SQL Replication (poorten 1433 en 4022)

### 10. match_vagrant_to_administrator  
Hier gaan we de standaard gebruikte account door onze Bento Boxes, "Vagrant", lid  maken van enkele belangrijke groepen voor Active Directory en SCCM. Dit om het gebruik van andere credentials en uitvoeren van commando's in een speciale sessie in de toekomst te vermijden.


# Deployment Server ( srv-SCCM):

## Deel 1: prerequisites en installatie SCCM

* [srv-SCCM_part1.ps1](../../provisioning/srv-SCCM_part1.ps1)

### 1. config_basics  
Net als voor srv-AD gaan we ipv6 uitschakelen en de interfaces hernoemen voor duidelijkheid. We stellen de default gateway en dns server adressen ook in met de ip van srv-AD, die deze rollen opneemt.

### 2. join_domain  
Dit toestel moet lid worden van het domein. Om deze actie uit te kunnen voeren gebruiken we ook een credential.

  **REBOOT**

* [srv-SCCM_part2.ps1](../../provisioning/srv-SCCM_part2.ps1)

### 3. remote_delegate_control  
Wat moet gebeuren is dat srv-SCCM controle moet krijgen over de 'System Management' container. Dit is nodig om de SCCM omgeving juist te kunnen laten werken in het domein. Normaal gezien wordt dit gedaan vanop de AD Server. Het probleem is dat eerst srv-AD volledig geprovisioned wordt, daarna srv-SCCM volledig. Het probleem is dus dat we de controle over de container niet kunnen geven aan een toestel dat nog niet bestaat (nog niet geprovisioned is). Mijn oplossing is deze operatie remote uitvoeren op srv-AD tijdens de provisioning van srv-SCCM. Concreet zetten we een PSSession op en laten we alle nodige operaties lopen binnen een script blok dat uitgevoerd wordt via deze PSSession. Deze operaties behoren tot de meest complexe van de opstelling, zie [hier](http://justanothertechnicalblog.blogspot.com/2014/10/create-system-management-container-with.html) voor meer info.

### 4. install_adk2  
We gaan de setups met nodige functies van ADK en ADK PE silent laten uitvoeren. Dit is een offline install, de installatiebestanden werden reeds voorbereidend gedownload om tijd te besparen. ADK is een belangrijke requirement voor SCCM. Het is nodig om Windows 10 te kunnen deployen, de boot images worden er onder andere mee gegenereerd.

### 5. install_webserver  
De IIS webserver is een andere prerequisite voor SCCM. De nodige functies en subfuncties zijn nogal specifiek. Ik heb daarom gekozen deze één keer via de gui in te stellen en de keuzes als XML te laten exporteren. Wat hier staat is het installeren van de IIS Windows Feature aan de hand van die XML (`webserver_prereq_full.xml`).  
  * Features:
    * .Net Framework 3.5 Features [Install all sub features]
    * .Net Framework 4.5 Features [Install all sub features]
    * BITS
    * Remote Differential Compression  
  * Roles Services:  
    * Common HTTP Features – Default Document, Static Content.  
    * Application Development – .NET Extensibility 3.5 and 4.5. Select ASP .NET 3.5, ISAPI extensions, ASP .NET 4.5.
    * Security – Windows Authentication.
    * IIS 6 Management Compatibility – IIS Management Console, IIS 6 Metabase Compatibility, WMI Compatibility and IIS Management Scripts and Tools.

### 6. install_wsus  
Om later updates door te kunnen duwen naar clients hebben we WSUS (Windows Server Update Services) nodig. Eerst installeren we de nodige WindowsFeature. Dan voeren we de post-install silent uit. We geven de locatie op waar updates opgeslagen zullen worden (`C:\WSUS`) en geven de juiste string op voor onze SQL Server instantie (`srv-SCCM.thovan.gent`).  
**Opmerking**: *We voorzien WSUS maar zullen het niet verder gebruiken in de opstelling. De eindstap van de opgave was om een client correct te deployen. Het onderhouden van deze Client met updates maakte er geen deel van uit. Het zou ook extra netwerkverkeer hebben geintroduceerd in de opstelling.*

### 7. change_sql_logon  
We verranderen de logon account waarmee de SQL Server service gestart wordt. Dit om connectie problemen te vermijden tijdens de installatie van SCCM. Er wordt verwacht dat deze logon hetzelfde is als de hostname, 'srv-SCCM' dus.

### 8. extend_ad_schema  
Een andere SCCM preresuisite: het active directory schema uitbreiden. Dit kan gedaan worden via een exe die hier speciaal voor dient, in de installatiemedia van SCCM. Om deze exe juist te kunnen laten uitvoeren moeten we weer hogere provileges hebben dan wat de standaard "Vagrant" account heeft. Deze keer gebruiken we een credential object met de rechten van de "Administrator" account.  
**Opmerking**: *Het extenden van het AD schema wordt voor een tweede keer gedaan. Soms wordt dit niet correct uitgevoerd tijdens provisioning, zelf met aangepaste credentials. Meerwaals uitvoeren heeft overigens geen negatieve gevolgen.*

### 9. create_sql_user  
We moeten SQL Server kunnen gebruiken met de standaard gebruikte account 'Vagrant'. We stellen dus enkele queries op om 'Vagrant' een geldige SQL Server gebruiker te maken, deze kunnen daarna opgeroepen worden in Powershell via 'invoke-sqlcmd'.

### 10. correct_sql_name  
Een laatste SQL Server prerequisite om SCCM te kunnen laten installeren is de reeds bestaande server naam te verranderen naar de hostname. Deze moeten hetzelfde zijn. De techniek is hetzelfde als bij de vorige functie: nodige queries opstellen en uitvoeren via de Powershell SQL Server commandlet ervoor.

### 11. install_sccm  
De laatste en belangrijkste functie. Als voorbereiding hebben we eerst de volledige installatie via gui doorlopen om een setup.ini te kunnen genereren met de gewenste installatie parameters. Deze .ini roepen we op in de command line om de setup zonder gebruikersinteractie uit te kunnen voeren. Een opmerking hierbij is dat deze ini zich op een geldig netwerkpad moet bevinden. Hiervoor maken we de locatie van deze .ini een Windows share.  
Inhoud van `setup.ini`:
  ```ini
    [Identification]
    Action=InstallPrimarySite

    [Options]
    ProductID=EVAL # zelf in te stellen nadat ini gegenereerd is
    SiteCode=P01
    SiteName=Ronse Site
    SMSInstallDir=C:\Program Files\Microsoft Configuration Manager
    SDKServer=srv-SCCM.thovan.gent
    RoleCommunicationProtocol=HTTPorHTTPS
    ClientsUsePKICertificate=0
    PrerequisiteComp=1
    PrerequisitePath=C:\Sources\SC_Configmgr_SCEP_1902_updates
    ManagementPoint=srv-SCCM.thovan.gent
    ManagementPointProtocol=HTTP
    DistributionPoint=srv-SCCM.thovan.gent
    DistributionPointProtocol=HTTP
    DistributionPointInstallIIS=0
    AdminConsole=1
    JoinCEIP=0

    [SQLConfigOptions]
    SQLServerName=srv-SCCM.thovan.gent
    DatabaseName=CM_P01
    SQLSSBPort=4022

    [CloudConnectorOptions]
    ..
  ```


## Deel 2: configuratie binnen SCCM:

* [srv-SCCM_config.ps1](../../provisioning/srv-SCCM_config.ps1)

### 1. prepare_SCCM_cmdlet  
Voor we SCCM kunnen beheren vanuit powershell moeten we eerst de nodige Powershell commandlets importeren.
Dan maken we een Persisted Drive aan voor onze SCCM site "P01" en stellen we dit in als onze werk directory.

### 2. forestDiscovery  
Dit was niet echt deel van de opgave maar zorgt voor een meer volwaardige SCCM omgeving. We stellen 'Forest Discovery' in als een dsicovery methode. Op deze manier zullen we resources kunnen ontdekken in het domein.
Met het tweede commando zullen we de discuvery expliciet oproepen. [Als we dit niet doen kunnen we tijdens deployment moeite hebben om de client lid te maken van het domein.]

### 3. boundaries  
Hier stellen we grenzen in voor de SCCM omgeving. Grenzen zijn nodig om de client de site te kunnen laten vinden. Ook nodig door de Client voor het vinden van Applicaties, Boot Images en OS Images.
De methode hiervoor is om eerst een Boundary Group te maken. Dan maken we een Boundary aan ingesteld met de AD Site die we aan deze Boundary Group toevoegen.  
**Opmerking**: *Er werd voor Forest Discovery gekozen als discovery methode. Grenzen worden er automatisch mee ontdekt dus deze functie is in feite overbodig geworden.*

### 4. site_roles  
Optioneel. Hier kennen we relevante site rollen toe zoals:
    - ApplicationCatalogWebServicePoint
    - ApplicationCatalogWebsitePoint
    - FallbackStatusPoint

### 5. dist_point_pxe_settings  
We wijzigen de PXE instellingen op ons Distribution Point zodat we later via PXE Windows 10 zouden kunnen deployen. 

### 6. boot_images_settings  
We bereiden de Boot images voor. We stellen in dat deze moeten kunnen deployen vanuti PXE boot. Ook enabelen we Command Support. Hiermee kunnen we de opdrachtprompt openen tijdens deployment. Dit vergemakkelijkt troubleshooting. Wat ook niet vergeten mag worden is het distribueren van deze Boot Images.

### 7. client_install_settings  
Ik heb er voor gekozen Automatic Client Push in te stellen. Dit zorgt ervoor dat de Client automatisch geinstalleerd zal worden op door SCCM gedetecteerde netwerk resources. Eerst voegen we onze gebruikersaccount toe aan SCCM. Dan enabelen we Automatic Client Push. Dit zal nu uitgevoerd kunnen worden met de authorisatie van de juist toegevoegde gebruikersaccount 'Vagrant'.

### 8. create_network_access_account  
In versie '2012 R2' van SCCM was het nodig een network access account in te stellen om fouten tijdens deployment te vermijden. Dit is mogelijk het geval niet meer in deze versie, '1903'. Toch koos ik ervoor dit ook op te nemen in de provisioning.  
Deze techniek is overgenomen uit één van de bronnen maar had aanpassingen nodig.
Eigenlijk werken we analoog met hoe we het in de gui zouden doen. We vragen eerst de component "Software Distribution" op van onze Site. Dan is het de bedoeling dat we de EmbeddedPropertyList voor Network Access User Names aanvullen met onze Network Access Account (thovan\vagrant). Het probleem is dat deze EmbeddedPropertyList niet aangemaakt was na een clean install van SCCM. De oplossing was om i.p.v. de EmbeddedPropertyList op te vragen deze nieuw aan te maken. Dit is het verschilpunt met hoe in de [bron](https://www.oscc.be/sccm/configmgr/powershell/naa/Set-NAA-using-Powershell-in-CB/) wordt gewerkt. Deze oude techniek is ook te zien in `create_network_access_account_old`.

### 9. import_os  
Er is éénmalige voorbereiding nodig alvorens we een Windows 10 image kunnen importeren in SCCM:
  1. Download geldige Windows 10 iso.
  2. Open deze iso en haal de 'install.wim' er uit.
  3. Kopieer deze wim naar een geldig netwerkpad.  

  Het is de wim die we effectief toevoegen aan SCCM. Het laatste dat we doen is distribueren.  
  **Opmerking**: *De voorbereidingsstappen konden ook vrij eenvoudig gescript worden maar hadden de uitvoeringstijd dramatisch verlengd.*  

### 10. create_applications  
Het maken van een applicatie in SCCM bestaat telkens uit ruwweg dezelfde stappen:  
  1. Creeer de applicatie in SCCM.
  2. Maak een detectie clausule voor de applicatie.  
    Indien MSI is de productcode het eenvoudigst. Indien setup is het iets moeilijker en moeten we kijken naar zaken zoals het versienummer.
  3. Maak een deployment type voor de applicatie, voeg de detectie clausule hier aan toe.  
    Het belangrijkste is het installatie commando. Dit moet silent zijn, dus zonder user interactie. Om dit mogelijk te maken voor Adobe Reader was een speciaal programma, de 'Adobe Customization Wizard' nodig om een speciale setup.exe te genereren met silent opties ingebouwd.
  4. Distribueer de  applicatie.

**Extra**: Silent installs  
Dit is mijn manier om silent installs te maken, in mijn ogen het meest uitdagende aspect bij het toevoegen van applicaties in SCCM. Het is natuurlijk soms mogelijk om een setup.ini te gebruiken. Indien het een populaire applicatie is is Googelen mogelijk rapper.  
  1. Voer de installatie van de applicatie uit vanuit de command line, stel hier in dat er een logfile weggeschreven wordt. Maak in de wizard de gewenste instellingen.
  2. Haal uit deze logfile al de relevante variabelen.
  3. Gebruik herhaaldelijks deze variabelen in de command line en roep de wizard op om ze te controleren tot alles daar ingevuld is zoals het hoord.
  4. Het laatste is om silent opties toe te voegen in de command line (/S /q, verschilt per applicatie, tussen exe en msi). Dit commando is wat we moeten toevoegen aan het Deployment type.

### 11. prep_deployment 

Deze functie bestaat uit vijf delen:
  1. Device collection maken voor onze client.
  2. Computer informatie van de client (mac is belangrijkst) importeren, deze computer ook toevoegen aan net aangemaakte device collection. Soms duurt het een tijd voor de Client hier effectief verschijnt. We updaten daarom de memberships van de Device Collection om dit proces te versnellen.
  3. Aangepaste partitionering. Dit is nodig door een verschil in hoe de Task Sequence gebouwd wordt tussen de gui en cmdlet.
  4. De Task Sequence bouwen, de belangrijkse opties:  
      * Boot image opgeven.
      * OS opgeven.
      * Domein info meegeven zodat client er ook direct lid van wordt tijdens deployment.
      * De te isntalleren appliaties opgeven.
  5. De Task Sequence deployen naar de device collection gemaakt in stap 1.

# Windows 10 Client:

De client is een lege Windows 10 VM die we manueel aanmaken in Virtualbox. Hierbij stellen we PXE in als boot methode, wijzigen we de Nat interface naar een compatiblele (met de opstelling) Hostonly interface en zorgen we dat het MAC adres overeen komt met wat we ingesteld werd tijdens de provisioning van srv-SCCM.

# Extra info: Vagrant

* ModifyVM   
In de `Vagrantfile` staat een methode 'extra_vbox_settings' die adhv het de tool 'modifyvm' enkele Virtualbox instellingen van de srv-AD en srv-SCCM wijzigt. Deze instellingen zijn niet essentieel maar zorgen voor een aangenamere (grafische) ervaring. Het is daarom interessant deze hier even te overlopen:

  ```ruby
  def extra_vbox_settings(vm)
    vm.provider :virtualbox do |vbw|
      vbw.gui = true
      vbw.customize ["modifyvm", :id, "--vram", "256"]
      vbw.customize ["modifyvm", :id, "--accelerate3d", "on"]
      vbw.customize ["modifyvm", :id, "--accelerate2dvideo", "on"]
      vbw.customize ["modifyvm", :id, "--graphicscontroller", "vboxsvga"]
      vbw.customize ["modifyvm", :id, "--paravirtprovider", "default"] # "hyperv" is buggy?
      vbw.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
      vbw.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
      vbw.customize ["modifyvm", :id, "--memory", 4096]
      vbw.customize ["modifyvm", :id, "--cpus", 2]
    end
  end
  ```

* vagrant-reload  
Om te kunnen rebooten tijdens de uitvoer van onze scripts gebruiken we de plugin 'vagrant-reload'  
Op te roepen via bv `node.vm.provision :reload` in de Vagrantfile. Compatibiliteit met de gebruikte Windows 10 Benno Boxes is niet 100%, zelf niet na aanpassen van WinRM opties als volgt in `Vagrantfile`:
  ```ruby
  config.winrm.timeout = 200 # timeouts vergroten voor lange provisioning tijden
  config.winrm.retry_limit = 15
  config.winrm.retry.delay = 20
  config.winrm.ssl_peer_verification = false
  config.winrm.transport = :plaintext # WinRM moet plaintext werken, anders werkt de plugin niet
  config.winrm.basic_auth_only = true
  ```

# Reproductie:

1. Voeg volgende base boxes toe aan Vagrant:
    ```
    vagrant box add gusztavvargadr/windows-server
    vagrant box add gusztavvargadr/sql-server
    ```
2. Voeg de reboot plugin toe aan Vagrant:
    ```
    vagrant plugin install vagrant-reload
    ```
3. Maak een vagrant omgeving (in een gewenste map):
    ```
    vagrant init
    ```
4. Kopieer de vagrant skeleton  van bertvv <https://github.com/bertvv/vagrant-shell-skeleton> naar deze nieuwe Vagrant omgeving

5. Wijzig `Vagrantfile` en `vagrant-hosts.yml` als volgt:
    ```ruby
    ..
    Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
      config.ssh.insert_key = false
      config.winrm.timeout = 200
      config.winrm.retry_limit = 15
      config.winrm.retry.delay = 20
      config.winrm.ssl_peer_verification = false
      config.winrm.transport = :plaintext
      config.winrm.basic_auth_only = true
      hosts.each do |host|
        config.vm.define host['name'] do |node|
          node.vm.box = host['box'] ||= DEFAULT_BASE_BOX
          if(host.key? 'box_url')
            node.vm.box_url = host['box_url']
          end

          node.vm.hostname = host['name']
          node.vm.network :private_network, network_options(host)
          custom_synced_folders(node.vm, host)

          extra_vbox_settings(node.vm)
          
          # Run configuration script for the VM
          node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-step1.ps1'
          node.vm.provision :reload
          node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '-step2.ps1'
          if (host['name'] = 'srv-SCCM')
            #node.vm.provision :reload # geen tweede reboot nodig
            node.vm.provision 'shell', path: 'provisioning/' + host['name'] + '_config.ps1'
          end
        end
      end
    end
    ```
    ```yml
    - name: srv-AD
      ip: 192.168.56.31
      synced_folders:
        - src: H:\SHARED # de map waar al onze installatiemedia en pre-gedownloade bestanden staan
          dest: C:\Sources
    - name: srv-SCCM
      box: gusztavvargadr/sql-server
      ip: 192.168.56.32
      synced_folders:
        - src: H:\SHARED
          dest: C:\Sources
    ```
6. Download de nodige installatiebestanden:  
    * Windows 10 installatiemedia (iso)
    * MS ADK (voer uit en sla lokaal op voor latere offline install)
    * MS ADK PE (voer uit en sla lokaal op voor latere offline install)
    * SCCM (Voer setup uit om extra 'Sources' bestanden te kunnen downloaden, kies om deze lokaal op te slaan en breek install af eens voltooid)

7. Zorg voor volgende bestandsstructuur:
    * 'Sources' map:
        * ADK_NEW (bevat offline ADK bestanden)
        * ADK_PE_NEW (bevat offline ADK PE bestanden)
        * Windows10.iso (naam afhankelijk van gedownload bestand)
        * applicaties ->
            * 7-zip
            * Adobe Reader DC
            * notepad++
    * 'vagrant' map:
        * Provisioning ->
            * {0BA78A36-741F-4573-AAE4-1B2930AA3292} (Group policy)
            * {6EFCAB8F-75E9-48A6-8EE5-FFF481566812} (Group policy)
            * setup.ini
            * webserver_prereq_full.xml
            * wsus_prereq.xml
            * srv-SCCM.ps1 srv-SCCM-step1.ps1 srv-SCCM-step2.ps1 srv-SCCM_config.ps1
            * srv-AD.ps1 srv-AD-step1.ps1 srv-AD-step2.ps1

8. Configureer een lege Windows 10 VM in Virtualbox  
(zie: ## Windows 10 Client)

9. Provision srv-AD en srv-SCCM:
    ```
    vagrant up
    ```
10. Start de lege Windows 10 VM, druk f12 voor pxe boot, selecteer de task sequence.

# Test plan

1. Provisioning geeft geen fouten.
2. Client wordt gedeployed.
3. Client is lid van domein, gewenste applicaties zijn geinstalleerd.

# Test rapport:

1. 
[TODO]  

2. 
![in dev collection, client geinstalleerd](/img/client_in_sccm.JPG)
![overzicht task sequence execution](/img/ts_exec_overzicht.JPG)

3.  
![domain membership](/img/membership.JPG)
![working apps](/img/apps.JPG)


# Bronnen:

- [vagrant skeleton bertvv](https://github.com/bertvv/vagrant-shell-skeleton/)  
- [modifyvm cmd line tool](https://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm-general)  
- [silent install ADK and PXE](https://github.com/DeploymentResearch/DRFiles/blob/master/Scripts/Install-HYDWindowsADK10v1809.ps1)  
- [Prajwail Desai nieuwe SCCM install gids](https://www.prajwaldesai.com/sccm-1902-install-guide-using-baseline-media/)  
- [Fix voor falende install van adds in script](https://github.com/MicrosoftDocs/azure-docs/issues/26043)  
- [oplossing voor falende dhcp install]()  
- [blogpost sccm unattended install](https://msandbu.wordpress.com/2012/10/21/configuration-manager-2012-silent-install/)  
- [officieele docs voor unattended sccm isntall](https://docs.microsoft.com/en-us/sccm/core/servers/deploy/install/use-a-command-line-to-install-sites)  
- [Officiele docs betreffend cimsession en credentials als workaround voor unattended dhcp install](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential?view=powershell-6)  
- [system management container maken in powershell](http://justanothertechnicalblog.blogspot.com/2014/10/create-system-management-container-with.html)  
- [Techniek om adhv .ini SCCM te installeren](https://msandbu.wordpress.com/2012/10/21/configuration-manager-2012-silent-install/)  
- [Vorige maar van officiele MS docs, meer uitleg](https://docs.microsoft.com/en-us/sccm/core/servers/deploy/install/use-a-command-line-to-install-sites)  
- [Hoe domain te joinen in via PS](https://www.petri.com/add-computer-to-domain-powershell)  
- [Uitleg bij proberen extenden schema met foute credentials](https://www.windows-noob.com/forums/topic/4002-errors-on-install-sccm2012-need-help/)  
- [Hoe de role install te repliceren adhv XML gegenereerd bij vorige install](https://dirteam.com/sander/2012/09/12/reusing-a-role-installation-xml-file-in-windows-server-2012-to-install-the-active-directory-domain-services-role/)  
- [info over wat geldige SQL connection strings zijn](https://stackoverflow.com/questions/12336613/sql-network-interfaces-error-25-connection-string-is-not-valid-in-powershell)  
- [handige plugin om mogelijk te kunnen rebooten tijdens provisioning](https://github.com/aidanns/vagrant-reload)  
- [Hoe een GPO te back-uppen en later te importeren via PS](https://blog.netwrix.com/2019/04/11/top-10-group-policy-powershell-commands/) 
- [Hoe de reverse zone aanmaken in DNS via PS](https://adamtheautomator.com/powershell-dns/)  
- [WSUS installeren en configureren via PS](https://devblogs.microsoft.com/scripting/installing-wsus-on-windows-server-2012/)  
- [SQL Server log on account wijzigen via PS](https://devblogs.microsoft.com/scripting/use-powershell-to-change-sql-server-service-accounts/)  
- [Uitleg netsh command](http://winintro.ru/netsh_technicalreference.en/html/6d34d1e7-7f9d-451c-9e04-09ef5b714d3f.htm)  
- [Microsoft docs voor SCCM powershell cmdlet](https://docs.microsoft.com/en-us/powershell/sccm/overview?view=sccm-ps)  
- [Powershell uitvoeren op domeincontroller vanop afstand](https://www.mowasay.com/2017/04/connecting-to-a-remote-domain-controller-using-powershell/)  
- [Blogpost met uitleg om pxe boot te laten werken, extra dhcp opties](https://danielengberg.com/unknown-host-gethostbyname-failed-80072ee-sccm/)  
- [Overzicht van locaties van de Distribution Point logs](https://danielengberg.com/distribution-point-logs-in-sccm/)  
- [Instructies om extra disk partitioning stappen in task sequence op te kunnen nemen via powershell](https://arisaastamoinencom.blogspot.com/2017/08/sccm-ts-with-powershell.html)  
- [Network accesss account aanmaken met powershell](http://www.oscc.be/sccm/configmgr/powershell/naa/Set-NAA-using-Powershell-in-CB/)  
- [Variabelen gebruik in task sequences](https://www.scconfigmgr.com/2018/01/10/customize-task-sequences-in-configmgr-current-branch-using-powershell/)  
- [Officiele docs voor New-CMTasksequence](https://docs.microsoft.com/en-us/powershell/module/configurationmanager/new-cmtasksequence?view=sccm-ps)  
- [Uitleg over probleem met Windows 10 partitionering](https://www.windows-noob.com/forums/topic/16554-windows-10-disk-partition-discrepencies/)  
- [Blogpost met uitgebreide utileg over bovenstaand probleem](https://miketerrill.net/2017/07/12/configuration-manager-osd-recovery-partitions-and-mbr2gpt/)  
- [De reden waarom een applicatie niet op te nemen is in een Task Sequence, welke instelling gewijzigt moet worden](https://www.windows-noob.com/forums/topic/8426-application-not-available-to-select-from-list-in-install-application-task-sequence-step/)  

# Problemen:

*Niet zo belangrijk als de rest van de documentatie maar het schetst een beeld van hoe ik de opstelling heb uitgewerkt, waar ik moest troubleshooten.*

- adds probleem:  
script gedeelte ervoor werkte niet als verwacht   
-> reden was secure string declaratie, haakjes '()' nodig.
- dhcp problemen:  
omdat vagrant en niet administrator de acties uitvoerd om dhcp te configureren  
-> cimsession gebruiken om als administrator die ene taak uit te voeren
- nat probleem:  
remote access menu niet bruikbaar meer  
-> legacy mode instellen, te wijzigen met registry key
sccm server nog geen lid van domein
- geen internet op sccm server:  
-> default gateway stond niet ingesteld
- schema extenden gaat niet:  
-> omdat standaard gebruikersaccount vagrant geen lid is van domain administrators, credentials gebruiken
- webserver prerequisite te fijne config nodig om te scripten:  
-> als xml geexporteerd en opgezocht hoe XML config te gebruiken op AD server
- Voor wsus install moeite met vinden juiste connection sting, niet intuitief:  
-> SRV-SCCM ipv SRV-SCCM\MSSQLSERVER, instance naam mag niet niet meegegeven worden
- gpo's sql firewall settings:  
-> manueel aangemaakt, gebackupt om via het script op te roepen.
- nat script gedeelte werkt niet na reboot:  
-> geen oplossing gevonden, manueel instellen of andere manier vinden vinden voor NAT en dat scripten.
- gebackupte gpo's kunnen niet hresteld worden:  
-> import-gpo ipv restore-gpo gebruiken.
- wsus postinstall faalt:  
 -> permissies op gedeelde vagrant map volstaan niet, workaround is lokale map gebruiken.
- script nodig om log on user sql server te wijzigen: 
-> blogpost gevonden die het beschrijft, maar: thovan\vagrant niet genoeg permissies  (ssh error), thovan\administrator wel goed
- script gemaakt om user aan te maken:  
-> rclick make script in management studio
- error, naam sql server matcht niet met hostname:  
-> naam wijzigen gaat via stored procedure die ik reeds in windows server heb gebruikt
 - sccm omgeving configuratie: (zie script)
 - sccm forest zegt "insufficient rights"  
 -> controle niet correct gedelegeerd? > script aangepast, wordt nu op afstand uitgevoerd op srv-SCCM via PSSession
 - domein controller wordt niet ontdekt:  
 -> uitgesteld omdat het niet deel van de hoofdtaak uitmaakt
 - task sequence faalt in begin op client:  
 -> dhcp opties voor default route en dns server toevoegen.
 - task sequence faalt, partitie error:  
 -> task sequence opnieuw aanmaken omdat partitioning optie niet opgenomen is zoals in de gui, extra partitionering stappen aan script toegevoegd, in cli "onzichtbare" extra partitionerings stap opgenomen waar rekening mee gehouden moet worden.
 - task sequence error (the task sequence cannot run because the program files for P0100001 cannot be located on a distribution point):  
-> opgelost door user state migration uit te zetten
 - cannot access a disposed object bij het uittesten task sequence in powershell:  
 (-> alle task sequences verwijderen uit sccm en server herstarten)  
 -> nieuwe powershell sessie starten, config mngr console afsluiten.
- partitionering fouten:  
-> verschil tussen manueel en via powershell aangemaakte task sequence, bij de powershell ts gebeurt er partitionering achter de schermen, zoals aanmaken van de recovery partitie, die ik dus niet moest opnemen (zie bron)
- partitionering fout 2, 0x80070070 niet genoeg ruimte op partitie  
-> op intuitie eerste bios partitie verwijderd, op task sequence van az glorieux is deze ook niet aanwezig. Dit werkt.
- applicaties niet kunnen toevoegen aan task sequence:  
-> deployment slecht ingesteld, moest 'install for system met whether or not user is logged on' zijn ipv standaard 'isntall for user'
- unattended install genereren, windows system image manager faalt  
-> verkeerde adk versie, error image zit in git repo
- winrm error bij uitvoeren volledig ad script met reboot plugin:  
winrm defaults verhogen? winrm authenticatie faalt omdat srv-AD domein controller is geworden? 
-> opgelost door basic winrm authenticatie te gebruiken en plaintext (zie bron)
- script voor groepen toe te voegen aan vagrant faalt:  
-> server meegeven, was niet nodig bij manuele uitvoering in powershell
- reverse zone aanmaken faalt (cimexception):  
-> niet belangrijk genoeg, uitvoeren met cim sessie? later in script uitvoeren?
- provisioning faalt als NAT adapter uitgeschakeld wordt in provisioning script:  
-> optie in commentaar zetten
- setup.ini geeft fout over fqdn, niet indien manueel gedaan:  
-> setup.ini moet op valide netwerkpad staan
- setup.ini heeft syntax fouten:  
-> product key moet ingesteld worden in script file, EVAL in ons geval
- sccm install via setup.ini maakt geen psdrive aan:  
-> aanmaken psdrive extra stap in script gemaakt.
- content distribueren werkt niet in script:  
-> te vroeg na installtie door asynchrone taken? nochthans juist ingesteld adhv setup.ini install. 30 min wachten lost het op
- boot image id kan anders zijn na herinstallatie:  
-> script flexibeler gemaakt door id eerst op te vragen en variabelen te gebruiken.
- aangemaakte client wordt niet toegevoegd aan Widnows 10 device collection, zelf indien manueel gedaan:  
-> Dit neemt tijd, script toegevoegd dat memberships van collection update.
- script gedeelte voor maken network access account faalt:  
-> slechte credentials wanneer gebruikt tijdens provisioning, geen oplossing gevonden.
- task sequence 'disposedobjecterror' bij hergebruiken van secure string wachtwoord  
-> een variabele aanmaken per gebruik. secure string kan niet hergebruikt worden.
- na sccm isntall fouten bij oproepen sccm config script  
-> bij silent install werd slechte psdrive aangemaakt, moest scope global meekrijgen om persistent te maken.
- client wordt niet toegevoegd aan domein, applicaties niet geinstalleerd met exit code 617  
-> [thovan\vagrant had niet de domein join permissies, thovan\administrator wel]
- network access account maken werkt niet, valuelists prop is leeg  
-> schema moet eerst geextend zijn + script aanpassing nodig om telkens nieuwe proplist aan te maken ipv onbestaande proberen te gebruiken
- content kan niet gedistriburred worden naar ons distribution point  
-> pas beschikbaar 15 min na installatie sccm, om dit op te vangen in script is hierop testen in loop een mogelijke oplossing