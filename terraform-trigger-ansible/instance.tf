# create key pair
#resource "aws_key_pair" "terraform-ansible" {
#  key_name   = "terraform_key"
#  public_key = "${var.ssh_public_key}"
#}

# create security group
resource "aws_security_group" "terraform-ansible" {
  name        = "terraform-ansible-sg"
  description = "Allow SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


/*
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.example.public_key_openssh
}
*/

# create an instance
resource "aws_instance" "terraform-ansible" {
  ami           = "${data.aws_ami.amazon_linux_stable_latest.image_id}"
  instance_type = "t2.micro"
  key_name      = "terraform_key"
  #key_name      = "${aws_key_pair.terraform-ansible.key_name}"
  #key_name      = aws_key_pair.generated_key.key_name
  security_groups = ["${aws_security_group.terraform-ansible.name}"]

  tags = {
    Name = "terraform-ansible"
  }



connection {
    type     = "ssh"
    user     = "ec2-user"
    host     = self.public_ip
    password = ""
    private_key = file("terraform_key")
    #private_key = "${file("~/.ssh/id_rsa")}"
  }
/*
provisioner "local-exec" {
      # method 1: construct inventory from terraform state
      command = "ansible-playbook -i '${aws_instance.terraform-ansible.public_dns},' install-webserver.yml"

      # method 2: use terraform-inventory dynamic inventory script https://github.com/adammck/terraform-inventory
      # command = "sleep 90; ansible-playbook -i /usr/local/bin/terraform-inventory install-webserver.yml"
   }*/

provisioner "file" {
    source      = "install-webserver.yml"
    destination = "install-webserver.yml"
  }

provisioner "file" {
    source      = "index.html"
    destination = "index.html"
       }

provisioner "file" {
    source      = "ansible.cfg"
    destination = "ansible.cfg"
       }

}

#IP of aws instance retrieved
output "op1"{
value = aws_instance.terraform-ansible.public_ip
}

#IP of aws instance copied to a file ip.txt in local system
resource "local_file" "ip" {
    content  = aws_instance.terraform-ansible.public_ip
    filename = "ip.txt"
}

#connecting to the Ansible control node using SSH connection
resource "null_resource" "nullremote1" {
depends_on = [aws_instance.terraform-ansible] 
connection {
	type     = "ssh"
  user     = "ec2-user"
  host     = aws_instance.terraform-ansible.public_ip
  password = ""
  private_key = file("terraform_key")
}

#copying the ip.txt file to the Ansible control node from local system 
provisioner "file" {
    source      = "ip.txt"
    destination = "ip.txt"
       }

provisioner "remote-exec" {
    inline = [
      "sudo yum install python-pip -y",
      "sudo pip install ansible",
      #"cd /root/ansible_terraform/aws_instance/",
      "ansible-playbook install-webserver.yml",
      #"ansible-playbook -i '${aws_instance.terraform-ansible.public_dns},' install-webserver.yml",
    ]
  }



}

