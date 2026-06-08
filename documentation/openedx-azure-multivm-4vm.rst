Open edX Azure Fixed 4-VM Architecture
######################################

Goal
****

Deploy a safer fixed 4-VM Open edX layout on Azure without autoscale:

* App VM for LMS/CMS and public web access.
* Worker VM for Celery, Redis, and RabbitMQ.
* MySQL VM for relational data.
* MongoDB VM for course content.

This deployment path is intended for Open edX Koa. Before running the Ansible
playbook, make sure the configuration checkout and release variables use the
same Koa release.

Recommended for this repo:

::

   git checkout open-release/koa.master
   export OPENEDX_RELEASE=open-release/koa.master
   export CONFIGURATION_VERSION=open-release/koa.master

If you want the fixed Koa tag instead of the Koa master branch, use
``open-release/koa.3`` consistently for both variables and the checkout.

Deployable ARM files:

* ``templates/stamp/template-multivm-4vm.json``
* ``templates/stamp/parameters.multivm-4vm.example.json``

Architecture
************

::

   Internet
      |
      v
   VM-1 App
   Nginx + LMS + CMS
   Public IP: yes
      |
      +--> VM-2 Worker + Redis + RabbitMQ
      +--> VM-3 MySQL
      +--> VM-4 MongoDB

VM Roles
********

VM-1 App
========

Runs:

* Nginx
* LMS
* CMS / Studio
* edxapp

This is the only VM with a public IP.

VM-2 Worker + Cache + Queue
===========================

Runs:

* Celery worker
* Redis
* RabbitMQ

VM-3 MySQL
==========

Runs:

* MySQL

Use premium SSD and regular backup.

VM-4 MongoDB
============

Runs:

* MongoDB

Use premium SSD and regular backup.

Network
*******

The template creates:

* One VNet.
* App subnet: ``10.30.1.0/24``.
* Data subnet: ``10.30.2.0/24``.
* Public IP only on the app VM.
* Private IPs for worker, MySQL, and MongoDB.

Fixed private IPs:

::

   App:    10.30.1.10
   Worker: 10.30.1.11
   MySQL:  10.30.2.10
   Mongo:  10.30.2.11

Allowed Ports
*************

Public internet to App VM:

::

   80
   443
   18010

SSH:

::

   22

For production, set ``allowedSshSource`` to your public IP with ``/32``.

Internal services:

::

   App/Worker -> MySQL: 3306
   App/Worker -> MongoDB: 27017
   App/Worker -> Redis: 6379
   App/Worker -> RabbitMQ: 5672

Deployment Notes
****************

This template deploys the safe 4-VM Azure infrastructure and runs simple
bootstrap commands.

The default bootstrap commands are intentionally simple. For a full Open edX
production installation, replace these parameters:

* ``appBootstrapCommand``
* ``workerBootstrapCommand``
* ``mysqlBootstrapCommand``
* ``mongoBootstrapCommand``

The app and worker bootstrap commands must use the same Open edX secrets and
must point to:

::

   MySQL:  10.30.2.10
   Mongo:  10.30.2.11
   Redis:  10.30.1.11
   Rabbit: 10.30.1.11

Ansible Multi-Node Install
**************************

After the Azure VMs exist and SSH works between the Ansible control machine and
the four private IPs, use:

* ``playbooks/openedx_multivm_4vm.yml``
* ``playbooks/inventory-multivm-4vm.example.ini``
* ``playbooks/sample_vars/multivm-4vm.yml``

Example command:

::

   export OPENEDX_RELEASE=open-release/koa.master
   export CONFIGURATION_VERSION=open-release/koa.master

   ansible-playbook \
     -i playbooks/inventory-multivm-4vm.example.ini \
     playbooks/openedx_multivm_4vm.yml \
     -e @playbooks/sample_vars/multivm-4vm.yml

Before running it, replace every ``CHANGE_ME`` value in
``playbooks/sample_vars/multivm-4vm.yml`` and set the real LMS/Studio domains.

The playbook installs in this order:

1. MySQL.
2. MongoDB.
3. Worker, Redis, and RabbitMQ.
4. LMS/CMS app.

The first version is intentionally conservative. It installs the core LMS/CMS
stack and leaves optional services such as ecommerce, discovery, analytics,
notes, forum, xqueue, and blockstore disabled until the base 4-node deployment
is healthy.

Recommended VM Sizes
********************

For roughly 100-300 learners starting an exam together:

::

   App:    Standard_D4s_v3 or larger
   Worker: Standard_D4s_v3 or larger
   MySQL:  Standard_D4s_v3 or larger, premium SSD
   Mongo:  Standard_D4s_v3 or larger, premium SSD

Deploy Command
**************

::

   az deployment group create \
     --resource-group <resource-group> \
     --template-file templates/stamp/template-multivm-4vm.json \
     --parameters @templates/stamp/parameters.multivm-4vm.example.json \
     --parameters adminPassword='<strong-password>'

Azure Portal
************

Use ``templates/stamp/template-multivm-4vm.json`` for Custom deployment.
Use the example parameters file as a guide for the values to enter.
