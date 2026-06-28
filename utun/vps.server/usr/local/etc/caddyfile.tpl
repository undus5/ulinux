{
	order forward_proxy before respond
}
:443, __DOMAIN__ {
	forward_proxy {
		basic_auth __USER__ __PASS__
		hide_ip
		hide_via
		probe_resistance
	}
	respond "status: ok"
}
