shared_context 'cleanse AWS resources for the test' do
  before(:all) do
    @cleanse_templates = [
      'vpc_delete_instance_lb.pp.tmpl',
      'vpc_delete_intg.pp.tmpl',
      'vpc_delete_vpn.pp.tmpl',
      'vpc_delete_custg.pp.tmpl',
      'vpc_delete_vpng.pp.tmpl',
      'vpc_delete_sg.pp.tmpl',
      'vpc_delete_subnet.pp.tmpl',
      'vpc_delete_routet.pp.tmpl',
      'vpc_delete_vpc.pp.tmpl'
    ]
    @cleanse_config = {:name => @name,:lb_name => "#{@name}-lb", :region => @default_region, :ensure => 'absent'}
  end

  it 'shall delete all resources from the test' do
    @cleanse_templates.each do |template|
      manifest = PuppetManifest.new(template, @cleanse_config)
      puts "Deleting resource with manifest #{manifest.render}"
      manifest.apply
    end
  end
end

shared_context 'cleanse AWS resources for the test1' do
  before(:all) do
    @cleanse_templates = [
      'vpc_delete_instance_lb.pp.tmpl',
      'vpc_delete_intg.pp.tmpl',
      'vpc_delete_vpn.pp.tmpl',
      'vpc_delete_custg.pp.tmpl',
      'vpc_delete_vpng.pp.tmpl',
      'vpc_delete_sg.pp.tmpl',
      'vpc_delete_subnet.pp.tmpl',
      'vpc_delete_routet.pp.tmpl',
      'vpc_delete_vpc.pp.tmpl'
    ]
    @cleanse_config = {:name => @name,:lb_name => "#{@name}-lb", :region => @default_region, :ensure => 'absent'}
  end

  it 'shall delete all resources from the test' do
    @cleanse_templates.each do |template|
      manifest = PuppetManifest.new(template, @cleanse_config)
      puts "Deleting resource with manifest #{manifest.render}"
      manifest.apply
    end
  end
end
