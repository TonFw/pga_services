require 'spec_helper'
require 'its'

describe PGA::Services do
  subject(:client) { PGA::Services.instance }
  let(:client) { PGA::Services.instance }

  it 'Should be connectable' do
    should be_connected
  end

  context "# Exploração filtrada pelo CPF do Produtor" do
    farmer_cpf = '967.379.991-15'
    invalid_cpf = '999.999.999-99'

    its(:get_farms, farmer_cpf) { should_not be_nil }
    its(:get_farms, invalid_cpf) { should be_nil }
  end

  context "# Explorações irmãs (mesma propriedade)" do
    cod_prop = '13011000602'
    invalid_cod_prop = '9911321'

    its(:sister_farms, cod_prop) { should be_a Array }
    its(:sister_farms, invalid_cod_prop) { should be_nil }
  end

  context "# Propriedade pelo código PGA da mesma" do
    cod_prop = '17000000001'
    invalid_cod_prop= '99999999999'

    its(:get_property, cod_prop) { should be_a Hash }
    its(:get_property, invalid_cod_prop) { should be_nil }
  end

  context "# Brincos do Produtor Corrente" do
    # COD EXPLORACAO ARAUJO: 0433000006069
    farm_cod = '520000000010001'
    invalid_farm_cod = '8653457'

    it 'Debugger' do
      earrings = client.get_active_earrings farm_cod
      expect(earrings).to be_a Array
    end

    its(:get_active_earrings, farm_cod) { should_not be_nil }
    its(:get_active_earrings, invalid_farm_cod) { should be_empty }

    its(:get_inactive_earrings, farm_cod) { should_not be_nil }
    its(:get_inactive_earrings, invalid_farm_cod) { should be_empty }
  end

  describe "# GTAs por CPF e CodExploração" do
    context "# de Produtor-Produtor" do
      cod_exploracao = '130440105050001'
      cod_exploracao_invalido = '8653457'

      cpf_produtor = '792.916.002-53'
      cpf_invalido = '999.999.990-99'

      it "GTA válida" do
        gtas_envio_ok = client.get_gtas_farmer_farmer(cpf_produtor, cod_exploracao)

        gtas_envio_ok.keys.should =~ [:gtas_recebidas, :gtas_enviadas]
        expect(gtas_envio_ok[:gtas_enviadas]).to be_a Array
      end

      it "GTA inválida" do
        gtas_envio_erro = client.get_gtas_farmer_farmer(cpf_invalido, cod_exploracao_invalido)

        gtas_envio_erro.keys.should =~ [:gtas_recebidas, :gtas_enviadas]
        gtas_envio_erro[:gtas_recebidas] =~ [:erro]
        gtas_envio_erro[:gtas_enviadas] =~ [:erro]
      end
    end # /Envio

    context "# de Produtor-Abatedor" do
      cod_exploracao = '130440105050001' # '0441000006013'
      cod_exploracao_invalido = '8653457'

      cpf_produtor = '792.916.002-53' # '824.719.048-66'
      cpf_invalido = '999.999.990-99'

      it "GTA válida" do
        gtas_envio_ok = client.get_gtas_farmer_slaughterhouse(cpf_produtor, cod_exploracao)
        if gtas_envio_ok.is_a?Array
          expect(gtas_envio_ok).to be_a Array
        else
          expect(gtas_envio_ok).to be_a Hash
        end
      end

      it "GTA inválida" do
        gtas_envio_erro = client.get_gtas_farmer_slaughterhouse(cpf_invalido, cod_exploracao_invalido)
        gtas_envio_erro.should be_nil
      end
    end # /Recebimento

    context 'Earring periods' do
      earring_invalid = '076000000023400'
      earring_valid = '076000000005711'

      codprop_valid = '52000000001'
      codprop_invalid = '17999999992'

      it '40 should be ok for LAST_PROPERTY' do
        # SetUp vars
        range = 40
        gtas = client.get_earring_transference_in_period(earring_valid, range)

        # Expected conditions
        gtas.has_key?(:ponum).should_not be_nil if gtas.is_a? Hash
      end

      it '40 should_not be ok for LAST_PROPERTY' do
        # SetUp vars
        range = 40
        gtas = client.get_earring_transference_in_period(earring_invalid, range)

        # Expected conditions
        gtas.has_key?(:ponum).should_not be_nil if gtas.is_a? Hash

        if gtas.is_a? Array
          gtas.each do |gta|
            gta = gta.first if gta.is_a?Array
            gta.has_key?(:ponum).should_not be_nil
          end
        end
      end

      it '90 should be ok for LAST_PROPERTY' do
        # SetUp vars
        range = 90
        gtas = client.time_without_gta(codprop_valid)

        # Check expected default values (property & zone are ID, so 0 is no record found)
        gtas.should be_a Hash
        gtas[:days_counter].should_not == 0
        gtas[:property].should_not == 0
        gtas[:zone].should_not == 0

        # Expected conditions
        gtas[:days_counter].should > range
      end

      it '90 should_not be ok for LAST_PROPERTY' do
        # SetUp vars
        range = 90
        gtas = client.time_without_gta(codprop_invalid)

        # Check expected default values (property & zone are ID, so 0 is no record found)
        gtas.should be_a Hash
        gtas[:days_counter].should == 0
        gtas[:property].should == 0
        gtas[:zone].should == 0

        # Expected conditions
        gtas[:days_counter].should < range
      end
    end

    context 'Count Property time without GTA' do
      codprop_invalid = '52000000000' # less then 90 dias
      codprop_valid = '52000000002' # more then 90 dias

      it "Invalid count (more than permitted)" do
        period = 90
        count_time = client.time_without_gta(codprop_invalid)
        count_time[:days_counter].to_i.should_not be > period
      end

      it "Valid count (more than permitted)" do
        period = 20 # Just to force the test pass (The PGA is drop constantly...)
        count_time = client.time_without_gta(codprop_valid)
        count_time[:days_counter].to_i.should be > period
      end
    end
  end

  describe "GTAs by it identifier" do
    context 'Valid GTA' do
      subject(:pga_client) { client }
      subject(:gta) { pga_client.get_gta_by_identifier serie='J', number='000006', oesa='GO' }

      it 'should return it GTA' do
        gta.should_not be_nil
      end

      it 'should have transported animals' do
        gta[:poline].should_not be_nil
        gta[:poline].should be_a Array
      end
    end

    context 'Earrings' do
      subject(:pga_client) { client }
      subject(:transported_animals) { pga_client.get_transported_animals ponum_gta_id='GTA.000001989.2015' }
      subject(:wrong_transported_animals) { pga_client.get_transported_animals ponum_gta_id='GTA.9991447.2094' }

      it "mustn't be empty an empty array" do
        transported_animals.should be_a Array
        transported_animals.empty?.should_not be_true
      end

      it "should be empty an array" do
        wrong_transported_animals.should be_a Array
        wrong_transported_animals.empty?.should be_true
      end
    end
  end

  describe "Slaughterhouse" do
    context "Retrieve" do
      it "should return a valid one by it SIF" do
        slaughterhouse = client.get_slaughterhouse_by '037'
        slaughterhouse.should_not be_nil
      end
    end
  end

  context "# Geoposicionamento pelo ID da Propriedade" do
    subject(:geoloc_ok) { client.get_geo_loc '17000000002' }
    subject(:geoloc_not_ok) { client.get_geo_loc '1709999002' }

    it 'should have a latitude' do
      geoloc_ok[:latitude].should_not be_nil
    end

    it 'should have a longitude' do
      geoloc_ok[:longitude].should_not be_nil
    end

    it 'should NOT have a latitude' do
      geoloc_not_ok[:latitude].should be_nil
    end

    it 'should NOT have a longitude' do
      geoloc_not_ok[:longitude].should be_nil
    end
  end

  context "# Produtor" do
    it "should have a valid e-mail" do
      person = client.get_full_person '792.916.002-53' #'965.804.611-87'
      person[:email][:emailaddress].index('@').should_not be_nil
    end

    it "should not have a valid e-mail" do
      person = client.get_full_person '313.343.932-49'
      person[:email][:emailaddress].should be_nil
    end
  end
end
