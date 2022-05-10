class ServerInfo:

    def __init__(self, dc):
        self.dc = dc
        self.timezone = "America/New_York"
        self.ad_group = [
            "", "domaingroup"
        ]
        if dc == 'QTSMIAMI':
            self.domain = 'domain1'
            self.community_string = "example"
            self.trap = "1.1.1.1"
            self.ntp_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
            self.dns_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
        elif dc == 'PLAS':
            self.domain = 'domain2'
            self.community_string = "example"
            self.trap = "1.1.1.1"
            self.ntp_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
            self.dns_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]


        elif dc == 'DLAS':
            self.domain = 'domain3'
            self.community_string = "example"
            self.trap = "10.146.16.14"
            self.trap = "1.1.1.1"
            self.ntp_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
            self.dns_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
        elif dc == 'ATL':
            self.domain = 'us.saas'
            self.community_string = "example"
            self.trap = "1.1.1.1"
            self.ntp_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
            self.dns_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]

        elif dc == 'TOR':
            self.domain = 'domain4'
            self.community_string = "example"
            self.trap = "1.1.1.1"
            self.ntp_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
            self.dns_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]

        elif dc == 'VAN':
            self.domain = 'domain5'
            self.community_string = "example"
            self.trap = "1.1.1.1"
            self.ntp_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]
            self.dns_servers = [
                "", "1.1.1.1", "1.1.1.1"
            ]