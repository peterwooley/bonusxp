test:
	luacheck . && xmllint --noout *.xml

test-pre-commit:
	luacheck -q --formatter plain . && xmllint --noout *.xml
