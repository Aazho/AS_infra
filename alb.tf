# Creating External LoadBalancer
resource "aws_lb" "external-alb" {
  name               = "ExternalLB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.front_sg.security_group_id]
  subnets            = [element(module.vpc.public_subnets, 0), element(module.vpc.public_subnets, 1)]
}
resource "aws_lb_target_group" "target-elb" {
  name     = "albtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}
resource "aws_lb_target_group_attachment" "attachment" {
  target_group_arn = aws_lb_target_group.target-elb.arn
  target_id        = module.frontend.id
  port             = 80
depends_on = [
  module.frontend,
]
}
resource "aws_lb_target_group_attachment" "attachment2" {
  target_group_arn = aws_lb_target_group.target-elb.arn
  target_id        = module.frontend_2.id
  port             = 80
depends_on = [
  module.frontend_2.id,
]
}
resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-alb.arn
  port              = "80"
  protocol          = "HTTP"
default_action {
  type             = "forward"
  target_group_arn = aws_lb_target_group.target-elb.arn
}
}