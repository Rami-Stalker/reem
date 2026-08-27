import 'package:flutter/material.dart';

class QuantitySelector
    extends StatefulWidget {
  const QuantitySelector({
    super.key,
  });

  @override
  State<QuantitySelector>
      createState() =>
          _QuantitySelectorState();
}

class _QuantitySelectorState
    extends State<QuantitySelector> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),

      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(28),

        color: Colors.white,

        boxShadow: [

          BoxShadow(
            color:
                Colors.black.withOpacity(
                    .04),

            blurRadius: 20,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),

      child: Row(
        children: [

          const Text(
            'Quantity',

            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const Spacer(),

          _button(
            Icons.remove,
            () {
              if (qty > 1) {
                setState(() {
                  qty--;
                });
              }
            },
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 24,
            ),

            child: Text(
              qty.toString(),

              style: const TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          _button(
            Icons.add,
            () {
              setState(() {
                qty++;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _button(
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 42,
        height: 42,

        decoration: const BoxDecoration(
          shape: BoxShape.circle,

          gradient: LinearGradient(
            colors: [
              Color(0xffFF9EB5),
              Color(0xffFF5C8A),
            ],
          ),
        ),

        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }
}