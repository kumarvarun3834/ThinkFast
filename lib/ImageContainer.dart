import 'package:flutter/material.dart';
class ImageContainer extends StatelessWidget {
  ImageContainer(this.img,this.C,this.h,this.w,{super.key});
  String img;
  double h;
  double w;
  Color C;
  @override
  Widget build(BuildContext context) {
    return Image.asset(img
    ,width: w,height: h,color: C,);
  }
}