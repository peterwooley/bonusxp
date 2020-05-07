BUILD_DIR = ./release
FILES = BonusXP.*
DIR_NAME = BonusXP
VERSION = 1.0.0

build: clean
	mkdir -p ./$(BUILD_DIR)/$(DIR_NAME)
	cp $(FILES) ./$(BUILD_DIR)/$(DIR_NAME)

	cd $(BUILD_DIR)/; zip $(DIR_NAME)_$(VERSION).zip ./$(DIR_NAME)/*

clean:
	rm -rf $(BUILD_DIR)

test:
	luacheck .
