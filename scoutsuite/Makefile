SHELL=/bin/bash
SCOUTSUITE_PATH="./ScoutSuite"
VENV_DIR="scout-venv"

usage:
	@echo "USAGE:"
	@echo " "
	@echo '   $$ make <target_name>'
	@echo " "
	@echo " Targets: "
	@echo " "
	@echo "  [python-version] - to see the python versions installed."
	@echo "                     Note: This make file uses python3 as the python executable(link)"
	@echo "                     due to the python executable(link) version is 2.7."
	@echo " "
	@echo "  [python-make-venv] - to setup the venv virtual environment in this directory"
	@echo "                       that scout will execute in."
	@echo " "
	@echo "  [scout-clone] - to pull down the source code that will be used to run scout."
	@echo " "
	@echo "  [scout-init] - to activate the venv virtual environment, install the required"
	@echo "                 pips, and then output the version of scout."
	@echo " "
	@echo "  [scout-help] - to display the scout help."
	@echo " "
	@echo "  [scout-aws-help] - to display the scout help for the aws provider."
	@echo " "
	@echo "  [scout-version] - to display the version of scout."
	@echo " "
	@echo "  [scout-run] - to run scout against the account associated to the AWS_PROFILE"
	@echo "                enviropnment variable. Note: we are defaulting to run scout in the us-east-1 region."
	@echo " "
	@echo "  [references] - to display links that were helpful in making this make file."
	@echo " "

python-version:
	@python --version
	@python3 --version

python-make-venv:
	python3 -m venv ./$(VENV_DIR)

scout-clone:
		git clone https://github.com/nccgroup/ScoutSuite

scout-init:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	pip install -r requirements.txt; \
	python3 ./scout.py --version

scout-help:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	python3 ./scout.py --help

scout-aws-help:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	python3 ./scout.py aws --help

scout-version:
	@source ./$(VENV_DIR)/bin/activate; \
	cd $(SCOUTSUITE_PATH); \
	python3 ./scout.py --version

scout-run:
	@source ./$(VENV_DIR)/bin/activate; \
	if [ "" == "$(AWS_PROFILE)" ]; then \
	echo " "; \
		echo "Error: AWS_PROFILE environment variable is required to be set!"; \
		echo " "; \
	else \
	echo "AWS_PROFILE: $(AWS_PROFILE)"; \
	  cd $(SCOUTSUITE_PATH); \
	  python3 ./scout.py aws --profile $(AWS_PROFILE) -r REGIONS us-east-1; \
	fi \

references:
	@echo "https://makefiletutorial.com"
	@echo "https://github.com/nccgroup/ScoutSuite/wiki"
	@echo "https://github.com/nccgroup/ScoutSuite/wiki/Setup"
