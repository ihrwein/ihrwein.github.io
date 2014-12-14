---
layout: post
title: Linux Container Security, part II.
date: 2014-12-14 12:00:00
---
This is the second part of my posts about Linux Container Security. As the first one, this is in Hungarian.

---
## A Docker démon
Ugyan ha az alapvető  technológiákon egy támadó nem is talál fogást,
egy újabb támadási felületet nyit a Docker démon és annak menedzsment
interfésze. A démon az indulásakor létrehoz egy UNIX domain socketet,
mely egy REST (Representational State Transfer) API-t (Application
Programming Interface) nyújt a rá csatlakozó klienseknek.
Alapértelmezetten a socket-hez csak a rendszergazda felhasználó férhet
hozzá, így a Docker kliensnek rendszergazdai jogokkal kell futnia. Ha a
fájlrendszerbeli jogosultságait megváltoztatjuk, akkor mások számára is
lehetővé válik a Docker démon kezelése.

Biztonsági rést nyithat a rendszeren, ha az előbb említett socket-et
lecseréljük egy TCP socketre. Ha a portot nem védjük tűzfallal, akkor
könnyen rendszergazdai jogokat szerezhetnek a nyitott portra kapcsolódó
alkalmazások. Ha mégis muszáj TCP socketet használnunk, akkor
eléhelyezhetünk valamilyen tűzfalat vagy  HTTPS proxy-t tanúsítvány
alapú autentikációval.


## Linux Kernel Capability-k
Sokszor előfordulhat, hogy egy alkalmazás valamilyen rendszergazdai
jogosultságot igénylő feladatot akar végrehajtani, viszont mégsem kell
kihasználnia a root felhasználó minden képességét. Például lehetséges,
hogy egy program 1024 alatti porton akar figyelni, de nem szükséges
számára a rendszeren található összes fájl olvasása illetve módosítása.

A Linux kernelében megvalósították a root felhasználó jogainak
szétvágását úgynevezett Capabality-k (~képesség) formájában, amelyek
használatával finom módon adhatunk ki, vagy vonhatunk meg
jogosultságokat az egyes folyamatoktól. A libcontainer (a Docker által
használt konténer kezelő programkönyvtár) legújabb verziójában (2014.
dec. 13.) a következő capability-k vannak engedélyezve [9]:

* **CAP\_AUDIT\_WRITE**: kernel audit logjának módosítása
* **CAP_CHOWN**: fájlok UID-jeinek és GID-jeinek tetszőleges megváltoztatása
* **CAP\_DAC\_OVERRIDE**: írási, olvasási, futtatási jogosultság ellenőrzés (DAC) megkerülése
* **CAP_FOWNER**: kiterjesztett ACL (Access Control List)-ek módosítása; néhány fájlrendszerbeli jogosultág ellenőrzés kikapcsolása, ahol a folyamat és a fájl UID-jének meg kell egyezni
* **CAP_FSETID**: ne törölje a set UID vagy set GID biteket a fájlok módosításakor
* **CAP_KILL**: jogosultság ellenőrzés kikapcsolása szignálok küldésekor
* **CAP_MKNOD**: mknod használata
* **CAP\_NET\_BIND_SERVICE**: 1024 alatti portokra bindolás
* **CAP\_NET\_RAW**: RAW vagy PACKET socket-ek használata
* **CAP_SETFCAP**: fájl capability-k módosítása
* **CAP_SETGID**: folyamatok GID-jének tetszőleges módosítása
* **CAP_SETPCAP**: folyamatok saját (vagy öröklődő) capability halmazának módosítása (hozzáadni csak az engedélyezettekből lehet, több halmaz is van)
* **CAP_SETUID**: folyamatok UID-jének tetszőleges módosítása
* **CAP\_SYS\_CHROOT**: chroot használata

Az alapértelmezett beállításokon állandóan vitáznak, hiszen meg kell
találni a megfelelő pontot a biztonság és a használhatóság között, így
egy konténer indításakor engedélyezhetünk vagy letilthatunk egyéb
capability-ket is. Azt sem szabad elfelejteni, hogy az egyéb
technológiák is (például PID namespace, SELinux) használatban vannak.

Mint minden más kernel modul betöltéséhez vagy eltávolításához szükség
van a `CAP_SYS_MODULE` capability-re, ami alapértelmezetten nincs
bekapcsolva, így pl. az SELinux kernel moduljának eltávolítása sem
lehetséges konténerekből (alpértelmezett capability-kkel).

## SELinux és sVirt
Az SELinux (Security Enhanced Linux) az NSA (National Security Agency)
által fejlesztett MAC (Mandatory Access Control) technológia a Linux
kernelben. A DAC-tól eltérően, ahol olvasási, írási és futtatási
jogosultságokat adhatunk meg a fájlokra, itt címkéket kezelünk. Minden
folyamat és fájl rendelkezik egy címkével, az SELinux pedig azt
ellenőrzi, hogy egy adott címkéjű folyamat hozzáférhet-e egy adott
címkéjű objektumhoz. A jogosultságok beállítása nagyon finom
granularitású, valamint az objektum típusa sem mindegy (fájl, socket,
folyamat, stb.).

Az SELinux házirend kiértékelése csak a DAC jogosultságok ellenőrzése
után történik meg, így ha a DAC nem enged meg valamit, az az SELinux-ig
el sem jut.

A Docker és így a konténerek esetén az SELinux használatának három
célja van:
* a hoszt rendszer védelme az általa futtatott konténerektől,
* a konténerek védelme egymástól,
* a Docker démonban esetlegesen megtalálható biztonsági rések
  kihasználásából adódó károk minimalizálása.

Az sVirt az SELinux-ot használja fel a különböző virtualizációs
technológiákból adódó sebezhetőségek kezelésére. Enélkül a hypervisor
esetleges hibáját a vendég gépek kihasználhatják, ezzel pedig átvehetik
akár a hoszt rendszer felett is az irányítást. A Linux konténerek
esetén nincs hypervisor, így az sVirt használata méginkább ajánlott.

sVirt használata esetén a konténerekben futó folyamatok az
`svirt_lxc_net_t` címkét fogják kapni, ahogy az a következő ábrán láható:
![sVirt ps](/images/svirt-ps.png)

A konténerekben található fájloknak a címkéje `svirt_sandbox_file_t`:
![sVirt ls](/images/svirt-ls.png)

Az `svirt_lxc_net_t` típus bármit tehet az `svirt_sandbox_file_t` típusú
fájlokkal, ezenkívül olvashatja és futtathatja a legtöbb /usr alatti
fájlt a hoszton, viszont nincs más jogosultsága a rendszeren (nem
olvashatja a /root, /home, /var könyvtárakat, stb.).

Ez a módszer megoldja az (1)-es problémát, viszont a konténerek ezek
alapján hozzáférhetnének egymáshoz, hiszen mindnek ugyanaz a címkéje. A
megoldás a Multi Category Security.

## Multi Category Security
Az SELinux címke utolsó része határozza meg a biztonsági szintet és a
kategóriát. Amikor a Docker elindít egy konténert, az kapni fog egy
véletlen szintet (pl. a Docker démon PID-jéből származtatva) és két
kategóriát. A konténer belső folyamatai is ezeket a paramétereket
fogják használni, illetve a benne található fájlok és könyvtárak
címkéjében is megjelenik ez az érték.

A különböző kategóriájú konténerek ily módon nem férhetnek hozzá
egymáshoz. A kiosztható kombinációk száma a Red Het Enterpise Linux 7
rendszeren körülbelül 500 000 (1024 kategória lehet egy szinten, két
kategóriát használnak a konténerek és egy kategóriát fenntartottak,
vagyis körülbelül 1024*1024/2 ~ 524288 az egyszerre futtatható
konténerek száma). Az MCS egy találó ábrázolása a következő ábrán
látható.

![Multi Category Security](http://opensource.com/sites/default/files/resize/images/life-uploads/type-enforcement_06_tux-dog-leash-520x289.png)

A képen a konténerek típusának megfeleltethető a dog, a kategóriáknak
pedig a spot és fido. Az ábrán az látható, ahogy a kernel SELinux
alrendszere megakadályozza a fido kategóriájú, de dog típusú kutyának,
hogy megegye a spot kategóriájú ételt.

A konténerekben úgy tűnhet, mintha az SELinux ki lenne kapcsolva még
akkor is, ha a hoszt rendszeren enforcing módban működik. Ez direkt van
így, hiszen így a konténerekből nem lehet setenforce-szal az SELinux
működési módját átállítani.

### Problémák
Gyakran meg kell osztanunk a hoszt rendszer egy könyvtárát a
konténerrel, viszont az csak a `svirt_sandbox_file_t` típust tudja írni
és olvasni. A megoldás a megosztandó könyvtár címkéjének az átállítása
`svirt_sandbox_file_t` típusra.

## Seccomp
A Linux kernel seccomp [11] funkciója lehetővé teszi, hogy az egyes
folyamatok az indulásukkor megmondhassák, milyen rendszerhívásokra lesz
szükségük. Ezután a kernel megtilt számukra minden más rendszerhívást.
Ha az alkalmazás megpróbálja mégis használni valamelyik nem
megengedettet, a kernel leállítja az alkalmazást.

A seccomp használata lecsökkkenti a kernel alkalmazások felé mutatott
felszínét, így egy esetleges bug valamelyik rendszerhívásban csak az
azt kifejezetten igénylő programok esetén használható ki.

A Dockerben ugyan még nem használják, de a munka 2014 októberében
elkezdődött [11]. Az LXC-ben már elérhető, viszont a Docker által
elsődlegesen használt libcontainer még nem támogatja.

## Híresebb CVE-k

### CVE-2014-5277

A Docker kliens ha nem tud HTTPS-en kapcsolódni az image-eket tároló
registry-hez, visszaáll nyílt HTTP kapcsolatra. Ez lehetővé teszi egy
Man In The Middle támadónak, hogy az image-et és az autentikációs
adatokat megszerezze [12].

### CVE-2014-3499

A Docker 1.0 démon mindenki által olvashatóan hozza létre a menedzsment
socketet [13].

## Összefoglalás
A Linux konténerek osztoznak a hoszt rendszer kernelén, így a biztonság
még kritikusabb mint egy virtuális gép esetén. A Docker és az LXC, mint
a legelterjedtebb konténer megoldások számos módon izolálják a
konténereket, melyekből a következőket tekintettem át:
* Control Group-ok,
* Linux kernel Namespace-ek,
* a Docker démon,
* Linux kernel Capability-k,
* SELinux és sVirt,
* seccomp.

## Irodalomjegyzék

* [[7] Namespaces in operation, part 1: namespaces overview](http://lwn.net/Articles/531114/)
* [[8] capabilities - overview of Linux capabilities](http://man7.org/linux/man-pages/man7/capabilities.7.html)
* [[9] Container Specification - v1](https://github.com/docker/docker/blob/master/vendor/src/github.com/docker/libcontainer/SPEC.md)
* [[10] I am working on seccomp integration into docker for project Atomic.](https://lists.projectatomic.io/projectatomic-archives/atomic-devel/2014-October/msg00061.html)
* [[11] SECure COMPuting with filters]( https://www.kernel.org/doc/Documentation/prctl/seccomp_filter.txt)
* [[12] CVE-2014-5277]( http://www.cvedetails.com/cve/CVE-2014-5277/)
* [[13] CVE-2014-3499]( http://www.cvedetails.com/cve/CVE-2014-3499/)

