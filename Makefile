# SPDX-License-Identifier: GPL-3.0-only
# Copyright 2022-2023, Mattias Bengtsson <mattias.jc.bengtsson@gmail.com>

ARCH=x86_64
STREAM=stable

################################################################################

ISO=fedora-coreos-$(STREAM)-live.$(ARCH).iso
QCOW2=fedora-coreos-$(STREAM)-qemu.$(ARCH).qcow2.xz

OUT_ISO_SDA=dist/$(subst iso,sda.iso,$(ISO))
OUT_ISO_VDA=dist/$(subst iso,vda.iso,$(ISO))
OUT_QCOW2=dist/$(subst .xz,,$(QCOW2))

VM_NAME=fcos-$(STREAM)-$(ARCH)-test
VM_MEMORY_MB=2048
VM_VCPUS=2
VM_DISK_GB=10
VM_INSTALL_CMD=virt-install --name $(VM_NAME)                                  \
	                    --memory $(VM_MEMORY_MB)                           \
	                    --vcpus $(VM_VCPUS)                                \
	                    --console pty,target_type=virtio                   \
	                    --graphics none                                    \
	                    --network bridge:virbr0                            \
	                    --os-variant fedora-coreos-$(STREAM)

.PHONY: all                                                                    \
        clean                                                                  \
        distclean                                                              \
        install-dependencies                                                   \
        create-vm                                                              \
        create-vm-from-iso                                                     \
        undefine-vm

all: $(OUT_ISO_SDA) $(OUT_ISO_VDA) $(OUT_QCOW2)

.PRECIOUS: ext/%.iso ext/%.qcow2.xz ext/ dist/

clean:
	@rm -rf dist/ *.ign
distclean: clean
	@rm -rf ext/

install-dependencies:
	@echo o Installing OS Packages ...
	@sudo dnf install -y butane                                            \
	                     coreos-installer                                  \
	                     pipx                                              \
	                     virt-install
	@echo
	@echo Installing remarshal (via pipx) ...
	@pipx install remarshal

create-vm: QEMU_FLAG:="-fw_cfg name=opt/com.coreos/config,file=$$PWD/config.ign"
create-vm: $(OUT_QCOW2) config.ign undefine-vm
	@echo o Creating a VM from $< ...
	@$(VM_INSTALL_CMD) --import                                            \
	                   --qemu-commandline=$(QEMU_FLAG)                     \
	                   --disk size=$(VM_DISK_GB),backing_store=$$PWD/$<

create-vm-from-iso: $(OUT_ISO_VDA) undefine-vm
	@echo o Creating a VM from $< ...
	@$(VM_INSTALL_CMD) --disk size=$(VM_DISK_GB) --cdrom  $<

undefine-vm:
	@echo o Removing old VMs ...
	@{ virsh destroy $(VM_NAME);                                           \
	   virsh undefine --remove-all-storage $(VM_NAME);                     \
	 } |& (grep -Ev '^(|.+(domain is not running).+)$$' ||: )              \
	   |& (grep -Ev '^(|.+(failed to get domain).+)$$'  ||: )              \
	   | pr -to 2
	@echo

################################################################################

%/:
	@mkdir -p $@

%.ign: %.bu
	@yaml2json $< | butane --files-dir ~/.ssh/                             \
	                       --pretty                                        \
	                       --strict /dev/stdin                             \
	                       > $@
%: %.xz
	@unxz $<

ext/%.iso:      PLATFORM:=metal
ext/%.iso:      FORMAT:=iso
ext/%.qcow2.xz: PLATFORM:=qemu
ext/%.qcow2.xz: FORMAT:=qcow2.xz
ext/%: | ext/
	@echo o Fetching $@ ...
	@FILE=$$(coreos-installer download --architecture "$(ARCH)"            \
	                                   --stream       "$(STREAM)"          \
	                                   --platform     "$(PLATFORM)"        \
	                                   --format       "$(FORMAT)"          \
	                                   --directory    ./ext/);             \
	mv $$FILE $@
	@echo

dist/%.qcow2: ext/$(QCOW2) | dist/
	@echo o Decompressing $< ...
	@unxz -k $<
	@mv $(subst .xz,,$<) $@
	@echo

$(OUT_ISO_SDA): DISK:=/dev/sda
$(OUT_ISO_VDA): DISK:=/dev/vda

dist/%.iso: ext/$(ISO) config.ign | dist/
	@rm $@ 2>/dev/null || true
	@echo o Customizing $@ [DISK=$(DISK)] ...
	@coreos-installer iso customize --dest-device $(DISK)                  \
	                                --dest-ignition config.ign             \
	                                -o $@ $< 2>&1 | pr -to 2
	@echo
