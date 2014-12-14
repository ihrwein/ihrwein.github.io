---
layout: post
title: Linux Container Security, part I.
date: 2014-12-14 12:00:00
tags:
- cgroups
- linux kernel namespaces
---
One of my homework was to write something about security. I choosed this title,
hope someone will find it interesting. It's in Hungarian.

I split it into two parts. The first one is about cgroups, kernel namespaces.
The second one contains informations about the Docker daemon, Linux kernel Capabilities, SELinux & sVirt and seccomp. 

---

## Bevezető
A virtuális gépek (Virtual Machine - VM) elterjedésével lehetővé vált
egy hoszt vagy gazda operációs rendszeren több virtuális gépet futtatni
egy hypervisor-on keresztül. Ez a hypervisor elfogja a hoszt operációs
rendszerre veszélyes utasításokat, így egy virtuális gépből nehéz
ártani a gazdagépnek.

A Linux konténerek lényegében folyamatok jól szeparált csoportjai,
melyek a Docker [1] megjelenésével kezdtek elterjedni. A konténerekben
futó alklamazások többek között rendelkeznek saját felhasználókkal,
fájlrendszerrel, hálózati interfészekkel, ugyanakkor az egyes
konténerek osztoznak a hoszt rendszer kernelén és hypervisor sem
választja el őket a hardvertől, ami több biztonsági kérdést is felvet. 

Az internetről számos előre telepített és konfigurált image-et lehet
letölteni [2], melyek egy paranccsal már el is indíthatók. Érdekes
biztonsági kérdéseket vet fel, vajon károsíthatja-e a Dockert futtató
rendszert egy kártékony konténer.

Jelen fogalmazás keretében megpróbálok egy átfogó képet adni a Docker
és így a Linux konténerek által használt biztonsági technológiákról.

## Docker
A Docker technológia lehetővé teszi ,,könnyű”, hordozható alkalmazás
konténerek készítését, melyek képesek futni bármely Docker-t támogató
Linux rendszeren. A hagyományos, ,,telepítőt szállítunk” megoldással
ellentétben kész futtatási környezetet, konfigurációt ad az
alkalmazásokhoz és például lehetővé teszi, hogy egy Red Hat Enterprise
Linux 7-re fejlesztett alkalmazás a saját környezetében tudjon futni
egy Ubuntu Linux disztribúción.

A Docker több technológiára is épít, többek között a Control
Group-okra, kernel namespace-ekre, LXC-re [3] ahogy az az első ábrán
látható . Az általa indított folyamatokat különböző cgroup-okba
helyezi, így izolálja őket egymástól. Az egyes folyamatok különböző
kernel namespace-ekbe kerülnek, így rendelkezhetnek saját
fájlrendszerrel (mount  pontokkal), hálózati interfészekkel, egyedi
hosztnevekkel, felhasználókkal, stb.

A Docker a futtatási környezetet image-eknek nevezi. Egy ilyen image
lényegében egy hordozható chroot, ami több rétegből áll. Az egyes
rétegeket az AUFS (Advanced multi layered Unification File System)
kezeli, így egy fájl módosítása nem írja felül az eredeti tartalmat,
hanem egy új réteget eredményez ami elfedi az eredeti fájlt. Ezeknek a
rétegeknek veszi az unióját az AUFS, ami a végleges image-et
eredményezi.

Az image-ek egy minimális OS-t tartalmaznak a Linuxokon megszokott
fájlrendszerrel. A  Docker konténerek tulajdonképpen az image-ek futó
példányai. Ezek a konténerek osztoznak a hoszt rendszer kernelén,
felfoghatók jól izolált folyamatokként is. Fontos, hogy a konténerekben
egy folyamatnak mindig előtérben kell futnia. Egy folyamat esetén ez
triviális, több folyamat esetén egy init-et kell futtatni az előtérben,
ami a háttérben elindítja a konténer folyamatait.

![A Docker által használt technológiák](http://blog.docker.com/wp-content/uploads/2014/03/docker-execdriver-diagram.png)


Az image-eket kézzel is felépíthetjük, de használhatunk úgynevezett
Dockerfile-t is. Minden egyes sorában egy-egy lépés található, csomagok
telepítése, fájlok másolása, stb. A
{% highlight bash %}
docker build <Dockerfile-t tartalmazó könyvtár elérési útja>
{% endhighlight %}

paranccsal lehet az image készítést elindítani. Bővebben a
Dockerfile-okról a [5] hivatkozás alatt található információ.

## Control Group-ok
A Control Group-ok, röviden cgroup-ok [6] lehetővé teszik folyamatok
csoportokba rendezését, ezen csoportok erőforrás használatának
monitorozását, szabályozását és egymástól való izolációját. A cgroup-ok
a folyamatokat hierarchikus csoportokba rendezik, amelyekhez különböző
alrendszereket (subsytem) rendelnek.

### Alrendszerek
Az alrendszerek általában a csoportok erőforrás használatát
szabályozzák, a leggyakoribbak a következők.

* **blkio**: blokk eszközökhöz szabályozza a hozzáférést
* **cpu**: súlyozással szabályozza a hozzáférést a CPU sávszélességéhez, az ütemezőre van hatással 
* **cpuset**: az egyes cgroup-okat CPU magokhoz lehet rendelni (affinitás), illetve NUMA architektúra esetén memória node-okhoz
* **cpuacct**: automatikusan jelentést készít a felhasznált CPU erőforrásokról
* **devices**: eszközökhöz (/dev) szabályozza a hozzáférést típus (blokk, karakter), major és minor azonosító és jogosultság (létrehozás, olvasás, írás)
* **freezer**: a cgroup-ban futó folyamatokat megfagyasztja, vagy azokat újra elindítja
* **memory**: a memória használatról készít jelentést, illetve limitálja a maximálisan használható méretet
* **net_cls**: megjelöli a hálózati csomagokat egy osztály azonosítóval (classid)
* **perf_event**: lehetővé teszi a monitorozást a perf programmal
* **hugetlb**: lehetővé teszi nagyméretű virtuális lapok kezelését.

### Biztonság

A cgroup-ok a következő módokon tudják növelni a rendszerek
biztonságát: a cpu alrendszer segítségével megakadályozható, hogy az
egyes konténerek kiéheztessék egymást, a memory alrendszerrel
memórialimitet lehet beállítani az egyes konténerekre (ebbe a fájl
cache is beleszámít), a blkio alrendszerrel beállíthatunk egy maximális
sávszélességet, amellyel az egyes konténerek a blokkeszközökhöz (pl.
merevlemez) hozzáférhetnek, a device alrendszer szabályozhatja a
blokkeszközökhöz a hozzáférést.

A 1-3. pontokkal elkerülhető a konténerek túlzott erőforrás használata,
ami a teljes rendszer összeomlásához vezethet. A 4. ponttal pedig
folyamat szinten szabályozhatjuk a hozzáférést egyes eszközökhöz.

## Namespace-ek

A Linux kernel namespace-einek lényege, hogy egyes globális
erőforrásokat olyan módon lássanak az adott namespace tagjai, mintha az
adott erőforrásból lenne egy saját, izolált példányuk. Ezzel a
megközelítéssel elérhető, hogy folyamatok csoportja azt hihesse, hogy
nem fut más folyamat a rendszeren. 

### Az mnt namespace

A mnt namespace lehetővé teszi, hogy folyamatok egyes csoportjai
más-más mount pontokat lássanak és használhassanak, vagyis ha egy
fájlrendszert egy mnt namespace-ben csatoltak fel, akkor azt csak az
abban lévő folyamatok fogják látni. 

### Az uts namespace
Ez a namespace leheővé teszi, hogy a benne található folyamatok saját
host- és doménnévvel rendelkezzenek.

### Az IPC namespace
Izolálja a SystemV és a POSIX message queue IPC (Inter Process
Communication) technológiákat.

### A PID namespace

A PID (Process ID) namespace izolálja a PID értékek tartományát, vagyis
különböző PID namespace-ekben lévő folyamatoknak lehet azonos a PID-je.
Ezzel lehetővé válik például a namespace-enkénti saját init futtatás,
hiszen az 1-es PID-et is többször fel lehet használni. Egy folyamat
csak az alatta lévő PID namespace-ekbe tud küldeni kill szignált.

## A net namespace

A net namespace a hálózattal kapcsolatos erőforrásokat izolálja. A
különböző namespace-ekben található folyamatok saját IP (Internel
Protocol) címekkel, routing táblákkal, portokkal, stb. rendelkezhetnek.
Egy érdekes alkalmazása, amikor is több webszerver is figyel a 80-as
porton, természetesen különböző namespace-ekben.

## A user namespace

A user namespace izolálja a user és group ID-kat namespace-enként,
vagyis ezek az értékek eltérhetnek a namespace-en belül és kívül. Ez
lehetővé teszi, hogy egy folyamat alacsony jogosultságú felhasználóként
viselkedjen a namespace-en kívül, azon belül viszont rendszergazdaként.

## Biztonság
Az mnt namespace megakadályozza, hogy az egyes konténerek hozzáférjenek
egymás fájlrendszeréhez (hacsak nincs direkt megosztva egy adott
könyvtár). Az IPC namespace megakadályozza a konténerekben futó
folyamatok közötti kommunikációt. Az egyes folyamatok különböző PID
namespace-ekben nem küldhetnek egymásnak kill vagy ptrace szignálokat.
A net namespace lehetővé teszi, hogy a konténerek saját routing
táblákkal, vagy iptables tűzfalszabályokkal rendelkezzenek, így ha ezek
rosszul vannak konfigurálva, azok csak egy konténert érintenek, nem a
teljes rendszert. A user namespace-t használva a konténer root
felhasználója a konténeren kívül egy alacsony jogosultságú
felhasználóra lehet leképezve.

# Irodalomjegyzék

* [[1] What is Docker?](https://www.docker.com/whatisdocker/ "What is Docker?")
* [[2] Docker Hub](https://registry.hub.docker.com/ "Docker Hub")
* [[3] LinuxContainers.org](https://linuxcontainers.org/ "LinuxContainers.org")
* [[4]](http://blog.docker.com/wp-content/uploads/2014/03/docker-execdriver-diagram.png)
* [[5] Dockerfile reference](http://docs.docker.com/reference/builder/ "Dockerfile reference")
* [[6] CGROUPS](https://www.kernel.org/doc/Documentation/cgroups/cgroups.txt "CGROUPS")
 

